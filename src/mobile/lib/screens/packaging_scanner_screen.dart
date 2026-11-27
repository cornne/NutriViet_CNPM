import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../l10n/app_locale.dart';
import '../services/local_guest_store.dart';
import '../services/paddle_ocr_vl_service.dart';
import '../services/profile_service.dart';
import '../widgets/nutriviet_glass_modal.dart';
import '../widgets/nutriviet_notice.dart';

/// Pure geometry helpers for mapping on-screen viewfinder / interactive crop
/// boxes to exact normalized `[0.0..1.0]` image pixel coordinates.
class PackagingScannerMath {
  /// Maps a visible [frameRect] on a [viewportSize] screen displaying a
  /// `BoxFit.cover` camera preview of aspect ratio [previewImageAspect]
  /// (`width / height` in upright portrait orientation) to normalized image
  /// coordinates `[0.0..1.0]`.
  static Rect mapCoverFrameToImageNormRect({
    required Size viewportSize,
    required double previewImageAspect,
    required Rect frameRect,
  }) {
    final vw = math.max(1.0, viewportSize.width);
    final vh = math.max(1.0, viewportSize.height);
    final imgAspect = previewImageAspect > 0.05 ? previewImageAspect : (3.0 / 4.0);
    final screenAspect = vw / vh;

    final double renderedW;
    final double renderedH;
    if (screenAspect < imgAspect) {
      renderedH = vh;
      renderedW = vh * imgAspect;
    } else {
      renderedW = vw;
      renderedH = vw / imgAspect;
    }

    final dx = (renderedW - vw) / 2.0;
    final dy = (renderedH - vh) / 2.0;

    final left = ((frameRect.left + dx) / renderedW).clamp(0.0, 0.94);
    final top = ((frameRect.top + dy) / renderedH).clamp(0.0, 0.94);
    final right = ((frameRect.right + dx) / renderedW).clamp(left + 0.06, 1.0);
    final bottom = ((frameRect.bottom + dy) / renderedH).clamp(top + 0.06, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Computes the exact pixel rectangle where an image of [imageAspect]
  /// (`width / height`) renders inside [containerSize] using `BoxFit.contain`.
  static Rect computeContainImageRect({
    required Size containerSize,
    required double imageAspect,
  }) {
    final cw = math.max(1.0, containerSize.width);
    final ch = math.max(1.0, containerSize.height);
    final aspect = imageAspect > 0.05 ? imageAspect : 1.0;
    final containerAspect = cw / ch;

    final double w;
    final double h;
    if (aspect > containerAspect) {
      w = cw;
      h = cw / aspect;
    } else {
      h = ch;
      w = ch * aspect;
    }
    return Rect.fromLTWH((cw - w) / 2.0, (ch - h) / 2.0, w, h);
  }
}

enum _ScannerStage {
  liveCamera,
  cropReview,
  scanning,
  result,
  notFound,
}

enum _CropDragHandle { none, move, topLeft, topRight, bottomLeft, bottomRight }

/// Full-screen packaging label scanner with:
/// - Honest WYSIWYG framing (dimmed cutout scrim + actual native ROI crop)
/// - Bounded `BoxFit.contain` uploaded photo stage with interactive crop box
/// - Lightweight RepaintBoundary rendering (no per-tick glass shader jank)
/// - Strict fuzzy Ingredients-only OCR handling (ignores Nutrition Facts)
class PackagingScannerScreen extends StatefulWidget {
  final int userId;
  final String memberName;
  final bool isGuest;
  final bool skipCameraInitForTest;
  final Uint8List? initialGalleryBytesForTest;

  const PackagingScannerScreen({
    super.key,
    required this.userId,
    required this.memberName,
    this.isGuest = false,
    this.skipCameraInitForTest = false,
    this.initialGalleryBytesForTest,
  });

  @override
  State<PackagingScannerScreen> createState() => _PackagingScannerScreenState();
}

class _PackagingScannerScreenState extends State<PackagingScannerScreen>
    with WidgetsBindingObserver {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _brandEmerald = Color(0xFF34D399);

  CameraController? _cameraController;
  bool _isCameraInitializing = true;
  String? _cameraError;
  bool _torchOn = false;
  bool _isTakingPicture = false;
  Offset? _focusRingPoint;

  // Live camera framing mode: true = actually crop to glowing viewfinder box!
  bool _cropToCameraFrame = true;
  Size _lastCameraViewport = Size.zero;
  Rect _lastCameraFrameRect = Rect.zero;

  // Current scanner stage
  _ScannerStage _stage = _ScannerStage.liveCamera;

  // Uploaded / captured photo state (strictly separated: raw picked vs sent cropped)
  Uint8List? _rawGalleryBytes;
  String _activeFileName = 'label.jpg';
  double _galleryImageAspect = 0.75;
  bool _galleryCropEnabled = false;
  Rect _galleryCropNorm = const Rect.fromLTRB(0.06, 0.18, 0.94, 0.78);
  _CropDragHandle _activeHandle = _CropDragHandle.none;
  Offset _dragStartLocal = Offset.zero;
  Rect _dragStartNorm = Rect.zero;

  // Exact bytes sent to PaddleOCR (already cropped & compressed!)
  Uint8List? _sentImageBytes;
  bool _isAnalyzing = false;
  String? _ocrProgressMessage;
  String? _ocrStatsBadge;
  bool _ocrNutritionStripped = false;
  String? _ocrMatchedHeader;
  bool _notFoundNutritionDetected = false;
  bool _cameFromGallery = false;

  PaddleOcrCancelToken? _ocrCancelToken;

  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _labelTitleCtrl;
  late final TextEditingController _ingredientsCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _labelTitleCtrl = TextEditingController(
      text: AppLocale.t('Kết quả quét', 'Scan result'),
    );
    _ingredientsCtrl = TextEditingController();

    if (widget.initialGalleryBytesForTest != null) {
      _isCameraInitializing = false;
      _rawGalleryBytes = widget.initialGalleryBytesForTest;
      _cameFromGallery = true;
      _stage = _ScannerStage.cropReview;
      _decodeImageAspect(widget.initialGalleryBytesForTest!);
    } else if (!widget.skipCameraInitForTest) {
      _initLiveCamera();
    } else {
      _isCameraInitializing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (ctrl != null && ctrl.value.isInitialized) {
        _cameraController = null;
        ctrl.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null &&
          mounted &&
          _stage == _ScannerStage.liveCamera &&
          !widget.skipCameraInitForTest) {
        _initLiveCamera();
      }
    }
  }

  Future<void> _initLiveCamera() async {
    if (!mounted) return;
    setState(() {
      _isCameraInitializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = AppLocale.t(
            'Không tìm thấy camera trên thiết bị. Bạn vẫn có thể chọn ảnh từ thư viện.',
            'No camera found on this device. You can still pick a photo from gallery.',
          );
        });
        return;
      }

      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await ctrl.initialize();
      try {
        await ctrl.setFocusMode(FocusMode.auto);
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      final old = _cameraController;
      setState(() {
        _cameraController = ctrl;
        _isCameraInitializing = false;
        _torchOn = false;
      });
      await old?.dispose();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraError = e.code == 'CameraAccessDenied'
            ? AppLocale.t(
                'Ứng dụng cần quyền Camera để quét trực tiếp nhãn bao bì.',
                'Camera permission is required for live packaging scanning.',
              )
            : AppLocale.t(
                'Không thể khởi động camera (${e.code}). Hãy thử lại hoặc chọn ảnh từ thư viện.',
                'Unable to start camera (${e.code}). Please retry or pick from gallery.',
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _cameraError = AppLocale.t(
          'Không thể mở camera trực tiếp. Hãy chọn ảnh từ thư viện hoặc thử lại.',
          'Unable to open live camera. Pick a photo from gallery or retry.',
        );
      });
    }
  }

  Future<void> _pauseCameraPreviewSafely() async {
    final ctrl = _cameraController;
    if (ctrl != null && ctrl.value.isInitialized && !ctrl.value.isPreviewPaused) {
      try {
        await ctrl.pausePreview();
      } catch (_) {}
    }
  }

  Future<void> _resumeCameraPreviewSafely() async {
    final ctrl = _cameraController;
    if (ctrl != null && ctrl.value.isInitialized && ctrl.value.isPreviewPaused) {
      try {
        await ctrl.resumePreview();
      } catch (_) {}
    }
  }

  Future<void> _decodeImageAspect(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w > 0 && h > 0 && mounted) {
        setState(() => _galleryImageAspect = w / h);
      }
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      final next = !_torchOn;
      await ctrl.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _torchOn = next);
    } catch (_) {}
  }

  Future<void> _onTapCameraToFocus(
    TapDownDetails details,
    Size viewportSize,
  ) async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (_stage != _ScannerStage.liveCamera) return;

    final local = details.localPosition;
    final nx = (local.dx / math.max(1.0, viewportSize.width)).clamp(0.0, 1.0);
    final ny = (local.dy / math.max(1.0, viewportSize.height)).clamp(0.0, 1.0);
    setState(() => _focusRingPoint = local);
    try {
      await ctrl.setFocusPoint(Offset(nx, ny));
      await ctrl.setExposurePoint(Offset(nx, ny));
    } catch (_) {}
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (mounted && _focusRingPoint == local) {
        setState(() => _focusRingPoint = null);
      }
    });
  }

  Future<void> _returnToLiveCamera() async {
    _ocrCancelToken?.cancel();
    _ocrCancelToken = null;
    setState(() {
      _stage = _ScannerStage.liveCamera;
      _rawGalleryBytes = null;
      _sentImageBytes = null;
      _ocrStatsBadge = null;
      _ocrProgressMessage = null;
      _ocrNutritionStripped = false;
      _ocrMatchedHeader = null;
      _notFoundNutritionDetected = false;
      _cameFromGallery = false;
      _ingredientsCtrl.clear();
    });
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (!widget.skipCameraInitForTest) {
        await _initLiveCamera();
      }
    } else {
      await _resumeCameraPreviewSafely();
    }
  }

  void _returnToGalleryCrop() {
    _ocrCancelToken?.cancel();
    _ocrCancelToken = null;
    if (_rawGalleryBytes == null) {
      _returnToLiveCamera();
      return;
    }
    setState(() {
      _stage = _ScannerStage.cropReview;
      _galleryCropEnabled = true;
      _ocrProgressMessage = null;
    });
  }

  void _cancelActiveOcr() {
    _ocrCancelToken?.cancel();
    _ocrCancelToken = null;
    if (!mounted) return;
    if (_cameFromGallery && _rawGalleryBytes != null) {
      setState(() {
        _stage = _ScannerStage.cropReview;
        _ocrProgressMessage = null;
      });
    } else {
      _returnToLiveCamera();
    }
  }

  Future<void> _captureFromLiveCamera() async {
    if (_stage != _ScannerStage.liveCamera || _isTakingPicture) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      await _pickImageFromGallery();
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      HapticFeedback.mediumImpact();
      final xfile = await ctrl.takePicture();
      final rawBytes = await xfile.readAsBytes();
      if (!mounted) return;
      await _pauseCameraPreviewSafely();

      Rect? cropRect;
      if (_cropToCameraFrame &&
          _lastCameraViewport.width > 0 &&
          _lastCameraFrameRect.width > 0) {
        final previewImageAspect = ctrl.value.aspectRatio > 0
            ? (1.0 / ctrl.value.aspectRatio)
            : (3.0 / 4.0);
        cropRect = PackagingScannerMath.mapCoverFrameToImageNormRect(
          viewportSize: _lastCameraViewport,
          previewImageAspect: previewImageAspect,
          frameRect: _lastCameraFrameRect,
        );
      }

      setState(() {
        _isTakingPicture = false;
        _cameFromGallery = false;
        _rawGalleryBytes = rawBytes;
        _activeFileName = xfile.name;
      });
      await _runOcrOnBytes(
        rawBytes,
        fileName: xfile.name,
        normalizedCropRect: cropRect,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTakingPicture = false);
      showNutriVietNotice(
        context,
        AppLocale.t(
          'Không thể chụp ảnh từ camera: $e',
          'Unable to capture photo: $e',
        ),
        tone: NutriVietNoticeTone.error,
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isTakingPicture || _stage == _ScannerStage.scanning || _isAnalyzing) {
      return;
    }
    try {
      // Keep higher resolution (2048px) before user optionally crops small text;
      // native Android compressForOcr shrinks strictly AFTER cropping!
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      await _pauseCameraPreviewSafely();

      setState(() {
        _rawGalleryBytes = bytes;
        _sentImageBytes = null;
        _activeFileName = picked.name;
        _cameFromGallery = true;
        _galleryCropEnabled = false;
        _galleryCropNorm = const Rect.fromLTRB(0.06, 0.18, 0.94, 0.78);
        _stage = _ScannerStage.cropReview;
        _ocrStatsBadge = null;
        _ocrProgressMessage = null;
        _ingredientsCtrl.clear();
      });
      await _decodeImageAspect(bytes);
    } catch (e) {
      if (!mounted) return;
      showNutriVietNotice(
        context,
        AppLocale.t('Không thể mở ảnh: $e', 'Unable to open photo: $e'),
        tone: NutriVietNoticeTone.error,
      );
    }
  }

  Future<void> _confirmGalleryAndScan() async {
    final bytes = _rawGalleryBytes;
    if (bytes == null || bytes.isEmpty) return;
    await _runOcrOnBytes(
      bytes,
      fileName: _activeFileName,
      normalizedCropRect: _galleryCropEnabled ? _galleryCropNorm : null,
    );
  }

  Future<void> _runOcrOnBytes(
    Uint8List rawBytes, {
    required String fileName,
    Rect? normalizedCropRect,
  }) async {
    final cancelToken = PaddleOcrCancelToken();
    _ocrCancelToken = cancelToken;

    setState(() {
      _stage = _ScannerStage.scanning;
      _sentImageBytes = rawBytes;
      _ocrStatsBadge = null;
      _ocrNutritionStripped = false;
      _ocrMatchedHeader = null;
      _notFoundNutritionDetected = false;
      _ingredientsCtrl.clear();
      _ocrProgressMessage = AppLocale.t(
        'Đang tối ưu & cắt đúng khung ảnh...',
        'Cropping & optimizing image...',
      );
    });

    // Run native EXIF-aware crop + sharp JPEG compression ONCE so the preview
    // displays the EXACT cropped region sent to PaddleOCR-VL-1.6!
    final preparedBytes = await PaddleOcrVlService.optimizeBytesForUpload(
      rawBytes,
      normalizedCropRect: normalizedCropRect,
    );

    if (!mounted || cancelToken.isCancelled) return;
    final kb = (preparedBytes.length / 1024).round();
    setState(() {
      _sentImageBytes = preparedBytes;
      _ocrProgressMessage = AppLocale.t(
        'Đang đọc nhãn bằng AI Vision ($kb KB)...',
        'Scanning label with AI Vision ($kb KB)...',
      );
    });

    final ocrRes = await PaddleOcrVlService.recognizeImage(
      imageBytes: preparedBytes,
      fileName: fileName,
      skipOptimize: true,
      useDocOrientationClassify: true,
      useDocUnwarping: false,
      cancelToken: cancelToken,
      onProgress: (progress) {
        if (!mounted || cancelToken.isCancelled) return;
        setState(() => _ocrProgressMessage = progress.message);
      },
    );

    if (!mounted) return;
    final wasCancelled = cancelToken.isCancelled || ocrRes['cancelled'] == true;
    if (_ocrCancelToken == cancelToken) {
      _ocrCancelToken = null;
    }
    if (wasCancelled) return;

    if (ocrRes['success'] == true) {
      final hasIngredients = ocrRes['has_ingredients'] == true;
      final extracted = (ocrRes['text'] ?? '').toString().trim();
      final totalMs = (ocrRes['total_ms'] as num?)?.toInt() ?? 0;
      final secLabel = (totalMs / 1000).toStringAsFixed(1);
      final nutritionDetected = ocrRes['nutrition_detected'] == true;
      final matchedHeader = ocrRes['matched_header']?.toString();
      final fuzzyScore = (ocrRes['fuzzy_score'] as num?)?.toDouble() ?? 0.0;

      if (hasIngredients && extracted.isNotEmpty) {
        HapticFeedback.mediumImpact();
        final pct = fuzzyScore > 0 ? ' ${(fuzzyScore * 100).round()}%' : '';
        final engineLabel = (ocrRes['engine'] ?? 'AI Vision').toString().trim();
        setState(() {
          _ingredientsCtrl.text = extracted;
          _ocrNutritionStripped = nutritionDetected;
          _ocrMatchedHeader = matchedHeader;
          _ocrStatsBadge =
              '$engineLabel · ${secLabel}s · $kb KB${pct.isNotEmpty ? ' · Fuzzy$pct' : ''}';
          _stage = _ScannerStage.result;
          _ocrProgressMessage = null;
        });
      } else {
        HapticFeedback.lightImpact();
        setState(() {
          _notFoundNutritionDetected = nutritionDetected;
          _ocrProgressMessage = null;
          _stage = _ScannerStage.notFound;
        });
      }
    } else {
      final isAuthErr = ocrRes['auth_error'] == true;
      setState(() {
        _ocrProgressMessage = null;
        _stage = _cameFromGallery && _rawGalleryBytes != null
            ? _ScannerStage.cropReview
            : _ScannerStage.liveCamera;
      });
      if (_stage == _ScannerStage.liveCamera) {
        await _resumeCameraPreviewSafely();
      }
      if (!mounted) return;
      showNutriVietNotice(
        context,
        (ocrRes['message'] ??
                AppLocale.t(
                  'Lỗi nhận dạng ảnh PaddleOCR-VL-1.6.',
                  'PaddleOCR-VL-1.6 OCR error.',
                ))
            .toString(),
        tone: NutriVietNoticeTone.error,
        duration: const Duration(seconds: 5),
        actionLabel: isAuthErr ? AppLocale.t('Nhập token', 'Set token') : null,
        onAction: isAuthErr ? _openTokenConfigDialog : null,
      );
      if (isAuthErr) {
        _openTokenConfigDialog();
      }
    }
  }

  Future<void> _executeRealScan() async {
    final text = _ingredientsCtrl.text.trim();
    if (text.isEmpty) {
      showNutriVietNotice(
        context,
        AppLocale.t(
          'Vui lòng chụp nhãn bao bì hoặc nhập danh sách thành phần.',
          'Please capture a packaging label or enter ingredients.',
        ),
        tone: NutriVietNoticeTone.warning,
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    final resolvedTitle = _labelTitleCtrl.text.trim().isEmpty
        ? AppLocale.t('Kết quả quét', 'Scan result')
        : _labelTitleCtrl.text.trim();
    final res = widget.isGuest
        ? await LocalGuestStore.createLocalScan(
            rawText: text,
            labelTitle: resolvedTitle,
            memberName: widget.memberName,
          )
        : await ProfileService.createScan(
            userId: widget.userId,
            rawText: text,
            labelTitle: resolvedTitle,
            memberName: widget.memberName,
          );
    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    if (res['success'] == true) {
      Navigator.pop(context, res);
    } else {
      showNutriVietNotice(
        context,
        (res['message'] ??
                AppLocale.t(
                  'Không thể phân tích nhãn bao bì.',
                  'Unable to analyze packaging label.',
                ))
            .toString(),
        tone: NutriVietNoticeTone.error,
      );
    }
  }

  Future<void> _openTokenConfigDialog() async {
    final existing = await PaddleOcrVlService.resolveToken();
    if (!mounted) return;
    final tokenCtrl = TextEditingController(text: existing);
    try {
      await showNutriVietGlassDialog<void>(
        context: context,
        builder: (ctx) => NutriVietGlassDialog(
          title: Text(
            AppLocale.t(
              'Cấu hình AI Studio Token',
              'Configure AI Studio Token',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocale.t(
                  'Mặc định ứng dụng sử dụng Cloudflare Cloud OCR bảo mật (không cần nhập key). Để trống để dùng mặc định hoặc nhập AI Studio Token riêng của bạn.',
                  'By default, the app uses secure Cloudflare Cloud OCR (no key needed). Leave blank for default or enter your own AI Studio Token.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: AppLocale.t(
                    'Dán AI Studio Token...',
                    'Paste AI Studio Token...',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            NutriVietGlassPillButton(
              label: AppLocale.t('Hủy', 'Cancel'),
              variant: NutriVietGlassButtonVariant.neutral,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            NutriVietGlassPillButton(
              label: AppLocale.t('Lưu token', 'Save token'),
              onPressed: () async {
                await PaddleOcrVlService.saveToken(tokenCtrl.text);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!mounted) return;
                showNutriVietNotice(
                  context,
                  AppLocale.t(
                    'Đã lưu AI Studio Token cục bộ.',
                    'Saved AI Studio token locally.',
                  ),
                  tone: NutriVietNoticeTone.success,
                );
              },
            ),
          ],
        ),
      );
    } finally {
      tokenCtrl.dispose();
    }
  }

  void _openTextEditorSheet() {
    showNutriVietGlassSheet(
      context: context,
      isScrollControlled: true,
      anchor: NutriVietGlassSheetAnchor.attached,
      grabber: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                AppLocale.t(
                  'Nhập / Chỉnh sửa thành phần bao bì',
                  'Enter / Edit Packaging Ingredients',
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelTitleCtrl,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: InputDecoration(
                  labelText:
                      AppLocale.t('Tên nhãn / sản phẩm', 'Product / label name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ingredientsCtrl,
                maxLines: 5,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: InputDecoration(
                  labelText: AppLocale.t(
                    'Danh sách thành phần & mã E trên bao bì',
                    'Ingredient list & E-codes on packaging',
                  ),
                  hintText: AppLocale.t(
                    'Dán hoặc gõ thành phần sản phẩm...',
                    'Paste or type product ingredients...',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              NutriVietGlassPillButton(
                width: double.infinity,
                height: 50,
                label: AppLocale.t(
                  'Phân tích thành phần ngay',
                  'Analyze ingredients now',
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {});
                  _executeRealScan();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ocrCancelToken?.cancel();
    _cameraController?.dispose();
    _labelTitleCtrl.dispose();
    _ingredientsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Interactive Crop Gesture Handling (for Uploaded Gallery Photos)
  // ---------------------------------------------------------------------------
  _CropDragHandle _hitTestCropHandle(Offset local, Rect cropPx) {
    const hitR = 28.0;
    if ((local - cropPx.topLeft).distance <= hitR) return _CropDragHandle.topLeft;
    if ((local - cropPx.topRight).distance <= hitR) return _CropDragHandle.topRight;
    if ((local - cropPx.bottomLeft).distance <= hitR) return _CropDragHandle.bottomLeft;
    if ((local - cropPx.bottomRight).distance <= hitR) return _CropDragHandle.bottomRight;
    if (cropPx.contains(local)) return _CropDragHandle.move;
    return _CropDragHandle.none;
  }

  void _onCropPanStart(DragStartDetails d, Rect imageRect) {
    if (!_galleryCropEnabled) return;
    final cropPx = Rect.fromLTRB(
      imageRect.left + _galleryCropNorm.left * imageRect.width,
      imageRect.top + _galleryCropNorm.top * imageRect.height,
      imageRect.left + _galleryCropNorm.right * imageRect.width,
      imageRect.top + _galleryCropNorm.bottom * imageRect.height,
    );
    _activeHandle = _hitTestCropHandle(d.localPosition, cropPx);
    _dragStartLocal = d.localPosition;
    _dragStartNorm = _galleryCropNorm;
  }

  void _onCropPanUpdate(DragUpdateDetails d, Rect imageRect) {
    if (!_galleryCropEnabled || _activeHandle == _CropDragHandle.none) return;
    final dx = (d.localPosition.dx - _dragStartLocal.dx) / math.max(1.0, imageRect.width);
    final dy = (d.localPosition.dy - _dragStartLocal.dy) / math.max(1.0, imageRect.height);
    const minSpan = 0.14;

    var l = _dragStartNorm.left;
    var t = _dragStartNorm.top;
    var r = _dragStartNorm.right;
    var b = _dragStartNorm.bottom;

    switch (_activeHandle) {
      case _CropDragHandle.move:
        final w = r - l;
        final h = b - t;
        l = (l + dx).clamp(0.0, 1.0 - w);
        t = (t + dy).clamp(0.0, 1.0 - h);
        r = l + w;
        b = t + h;
        break;
      case _CropDragHandle.topLeft:
        l = (l + dx).clamp(0.0, r - minSpan);
        t = (t + dy).clamp(0.0, b - minSpan);
        break;
      case _CropDragHandle.topRight:
        r = (r + dx).clamp(l + minSpan, 1.0);
        t = (t + dy).clamp(0.0, b - minSpan);
        break;
      case _CropDragHandle.bottomLeft:
        l = (l + dx).clamp(0.0, r - minSpan);
        b = (b + dy).clamp(t + minSpan, 1.0);
        break;
      case _CropDragHandle.bottomRight:
        r = (r + dx).clamp(l + minSpan, 1.0);
        b = (b + dy).clamp(t + minSpan, 1.0);
        break;
      case _CropDragHandle.none:
        break;
    }

    setState(() {
      _galleryCropNorm = Rect.fromLTRB(l, t, r, b);
    });
  }

  void _onCropPanEnd(DragEndDetails _) {
    _activeHandle = _CropDragHandle.none;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF070C10),
        body: _stage == _ScannerStage.liveCamera
            ? _buildLiveCameraStage()
            : _buildBoundedPhotoStage(),
      ),
    );
  }

  // Lightweight high-FPS dark translucent header (zero heavy live glass shader!)
  Widget _buildTopBar({required bool showFlash}) {
    final hasLiveCam = showFlash &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleHeaderBtn(
                icon: hasLiveCam
                    ? (_torchOn
                        ? PhosphorIconsFill.lightning
                        : PhosphorIconsBold.lightning)
                    : (_stage != _ScannerStage.liveCamera
                        ? PhosphorIconsBold.arrowLeft
                        : PhosphorIconsBold.key),
                color: hasLiveCam
                    ? (_torchOn ? const Color(0xFFFBBF24) : _brandEmerald)
                    : Colors.white,
                onTap: hasLiveCam
                    ? _toggleTorch
                    : (_stage != _ScannerStage.liveCamera
                        ? _returnToLiveCamera
                        : _openTokenConfigDialog),
              ),
            ),
            Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(
                      text: 'Nutri',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'Viet',
                      style: TextStyle(color: _brandEmerald),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleHeaderBtn(
                    icon: PhosphorIconsBold.key,
                    color: _brandEmerald,
                    onTap: _openTokenConfigDialog,
                  ),
                  const SizedBox(width: 6),
                  _CircleHeaderBtn(
                    icon: PhosphorIconsBold.x,
                    color: Colors.white,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 1: Live Camera with True Dimmed Cutout Scrim & Framing Mode Toggle
  // ---------------------------------------------------------------------------
  Widget _buildLiveCameraStage() {
    final ctrl = _cameraController;
    final hasLiveCam = ctrl != null && ctrl.value.isInitialized;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;
        final topSafe = MediaQuery.paddingOf(context).top;
        final bottomSafe = MediaQuery.paddingOf(context).bottom;

        // Compute deterministic viewfinder rectangle strictly between top bar and bottom dock
        final topAreaEnd = topSafe + 126.0;
        final bottomAreaStart = vh - bottomSafe - 184.0;
        final availH = math.max(180.0, bottomAreaStart - topAreaEnd);
        final frameW = math.min(vw - 36.0, 440.0);
        final frameH = math.min(availH * 0.78, 300.0).clamp(170.0, 310.0);
        final frameLeft = (vw - frameW) / 2.0;
        final frameTop = topAreaEnd + (availH - frameH) / 2.0;
        final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);

        _lastCameraViewport = Size(vw, vh);
        _lastCameraFrameRect = frameRect;

        return Stack(
          children: [
            // 1. Live camera surface isolated in RepaintBoundary
            Positioned.fill(
              child: hasLiveCam
                  ? RepaintBoundary(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) =>
                            _onTapCameraToFocus(d, Size(vw, vh)),
                        child: _buildCoverCameraPreview(ctrl, Size(vw, vh)),
                      ),
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0A1F17), Color(0xFF09121B)],
                        ),
                      ),
                    ),
            ),

            // 2. Dimmed cutout scrim when "Trong khung" is active (makes ROI unmistakable!)
            if (hasLiveCam && _cropToCameraFrame)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CutoutScrimPainter(
                        cutout: frameRect,
                        borderRadius: 20,
                        scrimColor: Colors.black.withValues(alpha: 0.58),
                        borderColor: _brandEmerald,
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Subtle green full-screen border hint when "Toàn màn hình" is active
            if (hasLiveCam && !_cropToCameraFrame)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _brandEmerald.withValues(alpha: 0.45),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Focus tap ring
            if (_focusRingPoint != null)
              Positioned(
                left: _focusRingPoint!.dx - 30,
                top: _focusRingPoint!.dy - 30,
                child: IgnorePointer(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _brandEmerald, width: 2),
                    ),
                  ),
                ),
              ),

            // 5. Top bar + honest framing badge
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopBar(showFlash: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xC80F172A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _brandEmerald.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _cropToCameraFrame
                                  ? PhosphorIconsBold.crop
                                  : PhosphorIconsBold.cornersOut,
                              color: _brandEmerald,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _cropToCameraFrame
                                    ? AppLocale.t(
                                        'Chỉ quét trong khung · Tự lọc Thành phần',
                                        'Inside frame only · Auto-filters Ingredients',
                                      )
                                    : AppLocale.t(
                                        'Quét toàn màn hình · Tự bỏ bảng dinh dưỡng',
                                        'Full screen · Auto-strips Nutrition Facts',
                                      ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Camera initializing / error card centered cleanly
            if (!hasLiveCam)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _isCameraInitializing
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _brandEmerald,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppLocale.t(
                                'Đang mở camera...',
                                'Opening camera...',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : _buildCameraUnavailableCard(),
                ),
              ),

            // 7. Bottom controls: Mode Toggle Pill + Shutter Dock
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Clear 2-option framing toggle: Trong khung vs Toàn màn hình
                      _FramingTogglePill(
                        leftLabel: AppLocale.t('Trong khung', 'Inside frame'),
                        rightLabel: AppLocale.t('Toàn màn hình', 'Full frame'),
                        leftSelected: _cropToCameraFrame,
                        onSelectLeft: () {
                          HapticFeedback.selectionClick();
                          setState(() => _cropToCameraFrame = true);
                        },
                        onSelectRight: () {
                          HapticFeedback.selectionClick();
                          setState(() => _cropToCameraFrame = false);
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD80F172A),
                          borderRadius: BorderRadius.circular(48),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DockSideButton(
                              icon: PhosphorIconsBold.images,
                              label: AppLocale.t('Thư viện', 'Gallery'),
                              onTap: _isTakingPicture
                                  ? null
                                  : _pickImageFromGallery,
                            ),
                            const SizedBox(width: 22),
                            GestureDetector(
                              onTap: _isTakingPicture
                                  ? null
                                  : _captureFromLiveCamera,
                              child: Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _brandGreen,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    width: 3.2,
                                  ),
                                ),
                                child: Center(
                                  child: _isTakingPicture
                                      ? const SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const PhosphorIcon(
                                          PhosphorIconsBold.camera,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 22),
                            _DockSideButton(
                              icon: PhosphorIconsBold.notePencil,
                              label: AppLocale.t('Nhập tay', 'Type'),
                              onTap: _openTextEditorSheet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCoverCameraPreview(CameraController ctrl, Size viewport) {
    final screenAspect = viewport.width / math.max(1.0, viewport.height);
    final previewAspect = ctrl.value.aspectRatio > 0
        ? (1.0 / ctrl.value.aspectRatio)
        : (3.0 / 4.0);
    var scale = screenAspect / previewAspect;
    if (scale < 1.0) scale = 1.0 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(ctrl)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGES 2–5: Bounded Photo Stage (ZERO Overflow! Strict SafeArea Column)
  // ---------------------------------------------------------------------------
  Widget _buildBoundedPhotoStage() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(showFlash: false),
          Expanded(
            child: switch (_stage) {
              _ScannerStage.cropReview => _buildCropReviewBody(),
              _ScannerStage.scanning => _buildScanningBody(),
              _ScannerStage.result => _buildResultBody(),
              _ScannerStage.notFound => _buildNotFoundBody(),
              _ScannerStage.liveCamera => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }

  /// Stage 2: Gallery / Uploaded Photo Preview + Interactive Crop Box
  /// Uses `BoxFit.contain` inside a strict bounded container so wide, tall, or
  /// square photos NEVER overflow or clip!
  Widget _buildCropReviewBody() {
    final bytes = _rawGalleryBytes;
    if (bytes == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Column(
            children: [
              _FramingTogglePill(
                leftLabel: AppLocale.t('Quét toàn ảnh', 'Full image'),
                rightLabel: AppLocale.t('Cắt vùng Thành phần', 'Crop Ingredients'),
                leftSelected: !_galleryCropEnabled,
                onSelectLeft: () {
                  HapticFeedback.selectionClick();
                  setState(() => _galleryCropEnabled = false);
                },
                onSelectRight: () {
                  HapticFeedback.selectionClick();
                  setState(() => _galleryCropEnabled = true);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _galleryCropEnabled
                    ? AppLocale.t(
                        'Kéo 4 góc hoặc di chuyển khung vào đúng đoạn Thành phần',
                        'Drag corners or move frame onto the Ingredients block',
                      )
                    : AppLocale.t(
                        'Sẽ gửi toàn bộ ảnh trong viền xanh · Tự lọc riêng Thành phần',
                        'Sends entire framed photo · Automatically filters Ingredients',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Strictly bounded dark preview canvas — ZERO overflow guaranteed!
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1621),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final imgRect = PackagingScannerMath.computeContainImageRect(
                      containerSize: boxSize,
                      imageAspect: _galleryImageAspect,
                    );
                    final cropPx = Rect.fromLTRB(
                      imgRect.left + _galleryCropNorm.left * imgRect.width,
                      imgRect.top + _galleryCropNorm.top * imgRect.height,
                      imgRect.left + _galleryCropNorm.right * imgRect.width,
                      imgRect.top + _galleryCropNorm.bottom * imgRect.height,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _onCropPanStart(d, imgRect),
                      onPanUpdate: (d) => _onCropPanUpdate(d, imgRect),
                      onPanEnd: _onCropPanEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Photo strictly contained — NEVER clipped or overflowing!
                          Center(
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          if (_galleryCropEnabled)
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _CutoutScrimPainter(
                                  cutout: cropPx,
                                  borderRadius: 12,
                                  scrimColor:
                                      Colors.black.withValues(alpha: 0.62),
                                  borderColor: _brandEmerald,
                                  drawCornerHandles: true,
                                ),
                              ),
                            )
                          else
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _FullImageOutlinePainter(
                                  rect: imgRect,
                                  borderColor: _brandEmerald,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Bottom actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _pickImageFromGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const PhosphorIcon(
                    PhosphorIconsBold.images,
                    size: 18,
                  ),
                  label: Text(
                    AppLocale.t('Ảnh khác', 'Change'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _confirmGalleryAndScan,
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsBold.scan,
                      size: 20,
                    ),
                    label: Text(
                      _galleryCropEnabled
                          ? AppLocale.t('Quét vùng đã cắt', 'Scan cropped area')
                          : AppLocale.t('Nhận dạng Thành phần', 'Scan Ingredients'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Stage 3: Running OCR — displays the EXACT cropped image sent to PaddleOCR!
  Widget _buildScanningBody() {
    final bytes = _sentImageBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        children: [
          // Exact sent image preview (BoxFit.contain, ZERO overflow)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1621),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _brandEmerald.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bytes != null)
                      Center(
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    const RepaintBoundary(
                      child: _LightweightScanBeam(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_brandEmerald),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _ocrProgressMessage ??
                            AppLocale.t(
                              'PaddleOCR-VL-1.6 đang đọc nhãn...',
                              'PaddleOCR-VL-1.6 reading label...',
                            ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _cancelActiveOcr,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocale.t('Hủy nhận dạng', 'Cancel OCR'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stage 4: Ingredients Found — crisp thumbnail + filtered ingredients card
  Widget _buildResultBody() {
    final bytes = _sentImageBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 140,
                width: double.infinity,
                color: const Color(0xFF0E1621),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _brandGreen.withValues(alpha: 0.35),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppLocale.t(
                            'THÀNH PHẦN ĐÃ LỌC',
                            'FILTERED INGREDIENTS',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _brandGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openTextEditorSheet,
                        style: TextButton.styleFrom(
                          foregroundColor: _brandGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const PhosphorIcon(
                          PhosphorIconsDuotone.notePencil,
                          size: 16,
                        ),
                        label: Text(
                          AppLocale.t('Chỉnh sửa', 'Edit'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_ocrStatsBadge != null)
                        _InfoChip(
                          icon: PhosphorIconsBold.scan,
                          text: _ocrStatsBadge!,
                          bg: const Color(0xFFE6F4EA),
                          fg: _brandGreen,
                        ),
                      if (_ocrMatchedHeader != null &&
                          _ocrMatchedHeader!.isNotEmpty)
                        _InfoChip(
                          icon: PhosphorIconsBold.magnifyingGlass,
                          text: '${AppLocale.t('Khớp', 'Matched')}: $_ocrMatchedHeader',
                          bg: const Color(0xFFECFDF5),
                          fg: const Color(0xFF065F46),
                        ),
                      if (_ocrNutritionStripped)
                        _InfoChip(
                          icon: PhosphorIconsBold.funnelSimple,
                          text: AppLocale.t(
                            'Đã lọc bỏ Bảng dinh dưỡng',
                            'Nutrition Facts stripped',
                          ),
                          bg: const Color(0xFFFEF3C7),
                          fg: const Color(0xFF92400E),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          _ingredientsCtrl.text,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isAnalyzing
                              ? null
                              : (_cameFromGallery
                                  ? _returnToGalleryCrop
                                  : _returnToLiveCamera),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _cameFromGallery
                                ? AppLocale.t('Cắt lại', 'Re-crop')
                                : AppLocale.t('Chụp lại', 'Retake'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _isAnalyzing ? null : _executeRealScan,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isAnalyzing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    AppLocale.t(
                                      'Phân tích dị ứng ngay',
                                      'Analyze allergies now',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stage 5: No Ingredients / Thành phần Found (e.g. Nutrition Facts only)
  Widget _buildNotFoundBody() {
    final bytes = _sentImageBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          if (bytes != null)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0E1621),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: PhosphorIcon(
                          PhosphorIconsDuotone.warningCircle,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocale.t(
                          'Không tìm thấy mục Thành phần',
                          'No Ingredients Section Found',
                        ),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _notFoundNutritionDetected
                      ? AppLocale.t(
                          'Ảnh chụp có chứa Bảng dinh dưỡng nhưng không có mục Thành phần (Ingredients). NutriViet chỉ phân tích thành phần — hãy xoay bao bì sang phần Thành phần hoặc cắt lại đúng khung.',
                          'This photo contains a Nutrition Facts table without an Ingredients section. NutriViet only analyzes Ingredients — turn the package to the Ingredients list or re-crop.',
                        )
                      : AppLocale.t(
                          'Không phát hiện mục Thành phần (Ingredients) rõ ràng trong ảnh. Hãy đưa camera lại gần dòng Thành phần, đủ sáng và thử lại.',
                          'No clear Ingredients section was detected in this photo. Move closer to the Ingredients text with good lighting and retry.',
                        ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_cameFromGallery && _rawGalleryBytes != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: _returnToGalleryCrop,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              AppLocale.t('Cắt lại khung', 'Adjust crop'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: _cameFromGallery
                            ? OutlinedButton(
                                onPressed: _pickImageFromGallery,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  AppLocale.t('Chọn ảnh khác', 'Other photo'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: _returnToLiveCamera,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brandGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  AppLocale.t('Chụp lại', 'Retake'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _openTextEditorSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brandGreen,
                          side: BorderSide(
                            color: _brandGreen.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(
                          AppLocale.t('Nhập tay', 'Type'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraUnavailableCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PhosphorIcon(
            PhosphorIconsDuotone.cameraSlash,
            size: 42,
            color: _brandGreen,
          ),
          const SizedBox(height: 12),
          Text(
            _cameraError ??
                AppLocale.t(
                  'Không thể mở camera trực tiếp.',
                  'Unable to open live camera.',
                ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _initLiveCamera,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F2937),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocale.t('Thử lại', 'Retry')),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _pickImageFromGallery,
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocale.t('Chọn ảnh', 'Pick photo')),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Lightweight Supporting Widgets & Painters (Zero Per-Frame Glass Shader Jank)
// =============================================================================

class _CircleHeaderBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleHeaderBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(child: PhosphorIcon(icon, color: color, size: 19)),
        ),
      ),
    );
  }
}

class _DockSideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DockSideButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: Center(
                child: PhosphorIcon(icon, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FramingTogglePill extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;

  const _FramingTogglePill({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onSelectLeft,
    required this.onSelectRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xD80F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(leftLabel, leftSelected, onSelectLeft),
          const SizedBox(width: 4),
          _buildSegment(rightLabel, !leftSelected, onSelectRight),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF14803C) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dimmed overlay outside [cutout] with crisp emerald corner brackets and
/// optional draggable corner dots so users see unambiguously what gets cropped.
class _CutoutScrimPainter extends CustomPainter {
  final Rect cutout;
  final double borderRadius;
  final Color scrimColor;
  final Color borderColor;
  final bool drawCornerHandles;

  const _CutoutScrimPainter({
    required this.cutout,
    required this.borderRadius,
    required this.scrimColor,
    required this.borderColor,
    this.drawCornerHandles = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutout, Radius.circular(borderRadius)),
      );
    final diff = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(diff, Paint()..color = scrimColor);

    // Thin border around cutout
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutout, Radius.circular(borderRadius)),
      Paint()
        ..color = borderColor.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Bold rounded corner brackets hugging the cutout RRect seamlessly
    final r = math.min(
      borderRadius,
      math.min(cutout.width, cutout.height) * 0.25,
    );
    final arm = math.min(26.0, math.min(cutout.width, cutout.height) * 0.22);
    final bracketPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(cutout.left, cutout.top + r + arm * 0.55)
        ..lineTo(cutout.left, cutout.top + r)
        ..quadraticBezierTo(cutout.left, cutout.top, cutout.left + r, cutout.top)
        ..lineTo(cutout.left + r + arm * 0.55, cutout.top),
      bracketPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(cutout.right - r - arm * 0.55, cutout.top)
        ..lineTo(cutout.right - r, cutout.top)
        ..quadraticBezierTo(cutout.right, cutout.top, cutout.right, cutout.top + r)
        ..lineTo(cutout.right, cutout.top + r + arm * 0.55),
      bracketPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(cutout.left, cutout.bottom - r - arm * 0.55)
        ..lineTo(cutout.left, cutout.bottom - r)
        ..quadraticBezierTo(cutout.left, cutout.bottom, cutout.left + r, cutout.bottom)
        ..lineTo(cutout.left + r + arm * 0.55, cutout.bottom),
      bracketPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(cutout.right - r - arm * 0.55, cutout.bottom)
        ..lineTo(cutout.right - r, cutout.bottom)
        ..quadraticBezierTo(cutout.right, cutout.bottom, cutout.right, cutout.bottom - r)
        ..lineTo(cutout.right, cutout.bottom - r - arm * 0.55),
      bracketPaint,
    );

    if (drawCornerHandles) {
      final dotFill = Paint()..color = Colors.white;
      final dotRing = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      for (final corner in [
        cutout.topLeft,
        cutout.topRight,
        cutout.bottomLeft,
        cutout.bottomRight,
      ]) {
        canvas.drawCircle(corner, 7.5, dotFill);
        canvas.drawCircle(corner, 7.5, dotRing);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CutoutScrimPainter oldDelegate) =>
      oldDelegate.cutout != cutout ||
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.drawCornerHandles != drawCornerHandles;
}

class _FullImageOutlinePainter extends CustomPainter {
  final Rect rect;
  final Color borderColor;

  const _FullImageOutlinePainter({
    required this.rect,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(10)),
      Paint()
        ..color = borderColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _FullImageOutlinePainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.borderColor != borderColor;
}

class _LightweightScanBeam extends StatefulWidget {
  const _LightweightScanBeam();

  @override
  State<_LightweightScanBeam> createState() => _LightweightScanBeamState();
}

class _LightweightScanBeamState extends State<_LightweightScanBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return FractionallySizedBox(
            heightFactor: 1.0,
            widthFactor: 1.0,
            child: Align(
              alignment: Alignment(0, -0.88 + _ctrl.value * 1.76),
              child: Container(
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0034D399),
                      Color(0x4D34D399),
                      Color(0xFF6EE7B7),
                      Color(0x4D34D399),
                      Color(0x0034D399),
                    ],
                    stops: [0.0, 0.35, 0.50, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

