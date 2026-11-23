import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_glass_modal.dart';
import '../widgets/nutriviet_notice.dart';
import '../widgets/nutriviet_shimmer.dart';
import '../widgets/nutriviet_ui.dart';
import 'admin_moderation_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Community Product Sharing Social Feed (Replaces Tab 1 Additives).
///
/// Key invariants:
/// - Guests are strictly gated from browsing or interacting with the feed and
///   prompted to sign in (with option to sync their local Guest data).
/// - User-generated content (post titles, brands, ingredients, review notes,
///   comments) is displayed verbatim regardless of `AppLocale` UI language.
/// - Hidden Admin controls (`role == 'admin'`) are only rendered for admins.
class CommunityFeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool embedded;
  final int refreshTick;
  final VoidCallback? onRequireAuth;

  const CommunityFeedScreen({
    super.key,
    required this.user,
    this.embedded = false,
    this.refreshTick = 0,
    this.onRequireAuth,
  });

  /// Opens the 120Hz Liquid Glass compose sheet (reusable from both Community
  /// tab and directly from Scan / History cards to share scanned products).
  static Future<bool> openComposeSheet({
    required BuildContext context,
    required Map<String, dynamic> user,
    String initialProductName = '',
    String initialBrand = '',
    String initialVerdict = 'GREEN',
    String initialIngredients = '',
    String initialContent = '',
  }) async {
    if (AuthService.isGuest(user)) {
      await showNutriVietGlassDialog(
        context: context,
        builder: (ctx) => NutriVietGlassDialog(
          title: Text(AppLocale.t('Cần đăng nhập', 'Sign In Required')),
          content: Text(
            AppLocale.t(
              'Chế độ Khách chỉ lưu dữ liệu trên máy. Hãy đăng nhập hoặc tạo tài khoản để chia sẻ sản phẩm lên Cộng đồng.',
              'Guest mode stores data locally only. Please sign in or create an account to share scanned products to the Community.',
            ),
          ),
          actions: [
            NutriVietGlassPillButton(
              height: 42,
              variant: NutriVietGlassButtonVariant.neutral,
              label: AppLocale.t('Để sau', 'Later'),
              onPressed: () => Navigator.pop(ctx),
            ),
            NutriVietGlassPillButton(
              height: 42,
              label: AppLocale.t('Đăng nhập', 'Sign In'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      );
      return false;
    }

    final token = (user['token'] ?? '').toString();
    final nameCtrl = TextEditingController(text: initialProductName);
    final brandCtrl = TextEditingController(text: initialBrand);
    final ingCtrl = TextEditingController(text: initialIngredients);
    final contentCtrl = TextEditingController(text: initialContent);
    final urlCtrl = TextEditingController();
    final picker = ImagePicker();

    String verdict = {'RED', 'YELLOW', 'GREEN'}.contains(initialVerdict.toUpperCase())
        ? initialVerdict.toUpperCase()
        : 'GREEN';
    Uint8List? pickedBytes;
    String pickedFilename = '';
    bool submitting = false;
    String? errMsg;
    bool posted = false;

    await showNutriVietGlassSheet(
      context: context,
      isScrollControlled: true,
      anchor: NutriVietGlassSheetAnchor.attached,
      grabber: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickPhoto(ImageSource source) async {
              try {
                final xfile = await picker.pickImage(
                  source: source,
                  maxWidth: 1280,
                  imageQuality: 78,
                );
                if (xfile == null) return;
                final bytes = await xfile.readAsBytes();
                if (!ctx.mounted) return;
                setModalState(() {
                  pickedBytes = bytes;
                  pickedFilename = xfile.name;
                  errMsg = null;
                });
              } catch (e) {
                setModalState(() {
                  errMsg = AppLocale.t(
                    'Không thể chọn ảnh: $e',
                    'Unable to pick image: $e',
                  );
                });
              }
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.t(
                        'Chia sẻ sản phẩm lên Cộng đồng',
                        'Share Product to Community',
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (errMsg != null) ...[
                      Text(
                        errMsg!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t('Tên sản phẩm *', 'Product name *'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: brandCtrl,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t('Thương hiệu (tùy chọn)', 'Brand (optional)'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocale.t('Mức đánh giá sau quét', 'Scan safety verdict'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _verdictChoiceChip(
                          label: AppLocale.t('An toàn', 'Safe'),
                          selected: verdict == 'GREEN',
                          color: const Color(0xFF14803C),
                          onTap: () => setModalState(() => verdict = 'GREEN'),
                        ),
                        const SizedBox(width: 8),
                        _verdictChoiceChip(
                          label: AppLocale.t('Thận trọng', 'Caution'),
                          selected: verdict == 'YELLOW',
                          color: const Color(0xFFD97706),
                          onTap: () => setModalState(() => verdict = 'YELLOW'),
                        ),
                        const SizedBox(width: 8),
                        _verdictChoiceChip(
                          label: AppLocale.t('Nguy hiểm', 'Danger'),
                          selected: verdict == 'RED',
                          color: const Color(0xFFDC2626),
                          onTap: () => setModalState(() => verdict = 'RED'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ingCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(
                          'Thành phần quét được',
                          'Scanned ingredients',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(
                          'Chia sẻ cảm nhận / cảnh báo của bạn',
                          'Your review or warning notes',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: NutriVietGlassPillButton(
                            height: 40,
                            variant: NutriVietGlassButtonVariant.neutral,
                            label: AppLocale.t('Chọn ảnh', 'Gallery'),
                            onPressed: submitting ? null : () => pickPhoto(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NutriVietGlassPillButton(
                            height: 40,
                            variant: NutriVietGlassButtonVariant.neutral,
                            label: AppLocale.t('Chụp ảnh', 'Camera'),
                            onPressed: submitting ? null : () => pickPhoto(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                    if (pickedBytes != null) ...[
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              pickedBytes!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                pickedBytes = null;
                                pickedFilename = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xB8000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const PhosphorIcon(
                                  PhosphorIconsBold.x,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: urlCtrl,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: AppLocale.t(
                            'Hoặc dán link ảnh Firebase/URL (tùy chọn)',
                            'Or paste Firebase/image URL (optional)',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    NutriVietGlassPillButton(
                      width: double.infinity,
                      height: 48,
                      isLoading: submitting,
                      label: AppLocale.t('Đăng lên Cộng đồng', 'Publish to Community'),
                      onPressed: () async {
                        if (submitting) return;
                        if (nameCtrl.text.trim().isEmpty) {
                          setModalState(() {
                            errMsg = AppLocale.t(
                              'Vui lòng nhập tên sản phẩm.',
                              'Please enter the product name.',
                            );
                          });
                          return;
                        }
                        setModalState(() {
                          submitting = true;
                          errMsg = null;
                        });

                        String finalImageUrl = urlCtrl.text.trim();
                        if (pickedBytes != null) {
                          final upRes = await CommunityService.uploadProductImage(
                            token: token,
                            bytes: pickedBytes!,
                            filename: pickedFilename.isEmpty ? 'photo.jpg' : pickedFilename,
                          );
                          if (!ctx.mounted) return;
                          if (upRes['success'] == true) {
                            finalImageUrl = (upRes['image_url'] ?? '').toString();
                          } else {
                            setModalState(() {
                              submitting = false;
                              errMsg = upRes['message']?.toString() ??
                                  AppLocale.t('Tải ảnh thất bại.', 'Image upload failed.');
                            });
                            return;
                          }
                        }

                        final res = await CommunityService.createPost(
                          token: token,
                          productName: nameCtrl.text,
                          brand: brandCtrl.text,
                          verdict: verdict,
                          ingredientsText: ingCtrl.text,
                          content: contentCtrl.text,
                          imageUrl: finalImageUrl,
                        );
                        if (!ctx.mounted) return;
                        if (res['success'] == true) {
                          posted = true;
                          Navigator.pop(ctx);
                        } else {
                          setModalState(() {
                            submitting = false;
                            errMsg = res['message']?.toString() ??
                                AppLocale.t('Đăng bài thất bại.', 'Failed to publish post.');
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    brandCtrl.dispose();
    ingCtrl.dispose();
    contentCtrl.dispose();
    urlCtrl.dispose();
    return posted;
  }

  static Widget _verdictChoiceChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFFF3F6F4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : const Color(0xFFD5E0DA),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _brandPurple = Color(0xFF4F37C8);
  static const Color _dangerRed = Color(0xFFDC2626);

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _posts = [];
  bool _loading = false;
  String? _error;
  String _verdictFilter = 'ALL';
  bool _includeHidden = false;

  bool get _isGuest => AuthService.isGuest(widget.user);
  bool get _isAdmin => AuthService.isAdmin(widget.user);
  String get _token => (widget.user['token'] ?? '').toString();
  int get _userId {
    final id = widget.user['id'];
    return id is int ? id : (int.tryParse('$id') ?? 0);
  }

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      _loadPosts();
    }
  }

  @override
  void didUpdateWidget(covariant CommunityFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.user['token'] != widget.user['token'] ||
            oldWidget.refreshTick != widget.refreshTick) &&
        !_isGuest) {
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (_isGuest) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await CommunityService.getPosts(
      token: _token,
      verdict: _verdictFilter,
      query: _searchCtrl.text.trim(),
      includeHidden: _isAdmin && _includeHidden,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _posts = List<Map<String, dynamic>>.from(res['posts'] ?? []);
      } else {
        _error = res['message']?.toString();
      }
    });
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final postId = post['id'] as int;
    final prevLiked = post['is_liked'] == true;
    final prevCount = (post['likes_count'] as int?) ?? 0;

    setState(() {
      _posts[index]['is_liked'] = !prevLiked;
      _posts[index]['likes_count'] = prevLiked ? (prevCount - 1) : (prevCount + 1);
    });

    final res = await CommunityService.toggleLike(token: _token, postId: postId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _posts[index]['is_liked'] = res['is_liked'] == true;
        _posts[index]['likes_count'] = res['likes_count'] ?? _posts[index]['likes_count'];
      });
    } else {
      setState(() {
        _posts[index]['is_liked'] = prevLiked;
        _posts[index]['likes_count'] = prevCount;
      });
    }
  }

  Future<void> _openCommentsSheet(int postIndex) async {
    final post = _posts[postIndex];
    final postId = post['id'] as int;
    final commentCtrl = TextEditingController();
    List<Map<String, dynamic>> comments = [];
    bool loading = true;
    bool sending = false;

    await showNutriVietGlassSheet(
      context: context,
      isScrollControlled: true,
      anchor: NutriVietGlassSheetAnchor.attached,
      grabber: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      builder: (ctx) {
        bool startedLoad = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> fetchComments() async {
              final res = await CommunityService.getComments(
                token: _token,
                postId: postId,
              );
              if (!ctx.mounted) return;
              setSheetState(() {
                loading = false;
                if (res['success'] == true) {
                  comments = List<Map<String, dynamic>>.from(res['comments'] ?? []);
                }
              });
            }

            if (!startedLoad) {
              startedLoad = true;
              fetchComments();
            }

            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocale.t('Bình luận', 'Comments'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: NutriVietShimmerBox(height: 54, borderRadius: 14),
                            )
                          : comments.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    AppLocale.t(
                                      'Chưa có bình luận nào. Hãy chia sẻ góc nhìn của bạn!',
                                      'No comments yet. Be the first to comment!',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: comments.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, cIdx) {
                                    final cm = comments[cIdx];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF6F9F7),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFE3EAE5),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      (cm['author_name'] ?? '').toString(),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                        color: Color(0xFF111827),
                                                      ),
                                                    ),
                                                    if (cm['author_role'] == 'admin') ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEDE9FE),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'ADMIN',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: _brandPurple,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Strict invariant: user comment content is displayed verbatim!
                                                Text(
                                                  (cm['content'] ?? '').toString(),
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    color: Color(0xFF1F2937),
                                                    height: 1.38,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (cm['can_delete'] == true)
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const PhosphorIcon(
                                                PhosphorIconsRegular.trash,
                                                color: _dangerRed,
                                                size: 17,
                                              ),
                                              onPressed: () async {
                                                final dRes = await CommunityService.deleteComment(
                                                  token: _token,
                                                  commentId: cm['id'] as int,
                                                );
                                                if (dRes['success'] == true && ctx.mounted) {
                                                  setSheetState(() {
                                                    comments.removeAt(cIdx);
                                                  });
                                                  if (mounted) {
                                                    setState(() {
                                                      _posts[postIndex]['comments_count'] =
                                                          comments.length;
                                                    });
                                                  }
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentCtrl,
                            style: const TextStyle(color: Color(0xFF111827)),
                            decoration: InputDecoration(
                              hintText: AppLocale.t(
                                'Viết bình luận...',
                                'Write a comment...',
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        NutriVietGlassPillButton(
                          height: 44,
                          isLoading: sending,
                          label: AppLocale.t('Gửi', 'Send'),
                          onPressed: () async {
                            final txt = commentCtrl.text.trim();
                            if (txt.isEmpty || sending) return;
                            setSheetState(() => sending = true);
                            final res = await CommunityService.addComment(
                              token: _token,
                              postId: postId,
                              content: txt,
                            );
                            if (!ctx.mounted) return;
                            setSheetState(() => sending = false);
                            if (res['success'] == true && res['comment'] is Map) {
                              commentCtrl.clear();
                              setSheetState(() {
                                comments.add(
                                  Map<String, dynamic>.from(res['comment'] as Map),
                                );
                              });
                              if (mounted) {
                                setState(() {
                                  _posts[postIndex]['comments_count'] = comments.length;
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    commentCtrl.dispose();
  }

  Future<void> _openReportDialog(int postId) async {
    final reasonCtrl = TextEditingController();
    await showNutriVietGlassDialog(
      context: context,
      builder: (ctx) => NutriVietGlassDialog(
        title: Text(AppLocale.t('Báo cáo bài viết', 'Report Post')),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: Color(0xFF111827)),
          decoration: InputDecoration(
            labelText: AppLocale.t(
              'Lý do báo cáo (VD: sai thông tin, spam...)',
              'Reason (e.g., inaccurate info, spam...)',
            ),
          ),
        ),
        actions: [
          NutriVietGlassPillButton(
            height: 42,
            variant: NutriVietGlassButtonVariant.neutral,
            label: AppLocale.t('Hủy', 'Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          NutriVietGlassPillButton(
            height: 42,
            variant: NutriVietGlassButtonVariant.danger,
            label: AppLocale.t('Gửi báo cáo', 'Submit Report'),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final res = await CommunityService.reportContent(
                token: _token,
                postId: postId,
                reason: reason,
              );
              if (!mounted) return;
              final ok = res['success'] == true;
              showNutriVietNotice(
                context,
                ok
                    ? AppLocale.t(
                        'Đã gửi báo cáo tới quản trị viên.',
                        'Report submitted to administrators.',
                      )
                    : (res['message']?.toString() ?? 'Error'),
                tone: ok ? NutriVietNoticeTone.success : NutriVietNoticeTone.error,
              );
            },
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
  }

  Future<void> _deleteOrModeratePost(Map<String, dynamic> post, String action) async {
    final postId = post['id'] as int;
    final Map<String, dynamic> res;
    if (action == 'hide' || action == 'unhide') {
      res = await CommunityService.moderatePost(
        token: _token,
        postId: postId,
        action: action,
        reason: action == 'hide'
            ? AppLocale.t('Ẩn bởi quản trị viên', 'Hidden by administrator')
            : '',
      );
    } else {
      res = await CommunityService.deletePost(token: _token, postId: postId);
    }
    if (!mounted) return;
    if (res['success'] == true) {
      await _loadPosts();
    } else {
      showNutriVietNotice(
        context,
        res['message']?.toString() ?? 'Error',
        tone: NutriVietNoticeTone.error,
      );
    }
  }

  Widget _buildGuestGate(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 130),
          child: NutriVietGlassCard(
            cornerRadius: 26,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NutriVietGlassIconTile(
                  icon: PhosphorIconsDuotone.usersThree,
                  color: _brandGreen,
                  size: 62,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocale.t(
                    'Mạng xã hội Cộng đồng',
                    'Community Network',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocale.t(
                    'Bạn đang dùng Chế độ Khách (lịch sử quét & hồ sơ được lưu trên thiết bị). Đăng nhập để chia sẻ sản phẩm quét, bình luận cùng cộng đồng và đồng bộ dữ liệu lên cloud.',
                    'You are in Guest Mode (scans & profiles are stored locally on this device). Sign in to share scanned products, join community discussions, and sync your local data to the cloud.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                NutriVietGlassPillButton(
                  width: double.infinity,
                  height: 48,
                  label: AppLocale.t('Đăng nhập để mở khóa', 'Sign In to Unlock'),
                  onPressed: () {
                    if (widget.onRequireAuth != null) {
                      widget.onRequireAuth!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                NutriVietGlassPillButton(
                  width: double.infinity,
                  height: 44,
                  variant: NutriVietGlassButtonVariant.neutral,
                  label: AppLocale.t('Tạo tài khoản mới', 'Create Account'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerdictBadge(String verdict) {
    final v = verdict.toUpperCase();
    final Color bg;
    final Color fg;
    final String label;
    if (v == 'RED') {
      bg = const Color(0xFFFEE2E2);
      fg = _dangerRed;
      label = AppLocale.t('Nguy hiểm · RED', 'Danger · RED');
    } else if (v == 'YELLOW') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = AppLocale.t('Thận trọng · YELLOW', 'Caution · YELLOW');
    } else {
      bg = const Color(0xFFDCFCE7);
      fg = _brandGreen;
      label = AppLocale.t('An toàn · GREEN', 'Safe · GREEN');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildPostCard(int index) {
    final post = _posts[index];
    final verdict = (post['verdict'] ?? 'GREEN').toString();
    final imageUrl = CommunityService.resolveMediaUrl((post['image_url'] ?? '').toString());
    final isHidden = post['status'] == 'hidden';
    final isLiked = post['is_liked'] == true;
    final canDelete = post['can_delete'] == true;
    final authorName = (post['author_name'] ?? 'User').toString();
    final authorInitial = authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U';

    return NutriVietGlassCard(
      cornerRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: post['author_role'] == 'admin'
                    ? const Color(0xFFEDE9FE)
                    : const Color(0xFFDFF3E6),
                child: Text(
                  authorInitial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: post['author_role'] == 'admin' ? _brandPurple : _brandGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (post['author_role'] == 'admin') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _brandPurple,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((post['brand'] ?? '').toString().isNotEmpty)
                      Text(
                        post['brand'].toString(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              _buildVerdictBadge(verdict),
            ],
          ),
          if (isHidden) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AppLocale.t('Bài viết đang bị Admin ẩn', 'Post hidden by Admin'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Strict invariant: user-authored product name, ingredients & review stay verbatim!
          Text(
            (post['product_name'] ?? '').toString(),
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          if ((post['content'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post['content'].toString(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                height: 1.42,
              ),
            ),
          ],
          if ((post['ingredients_text'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F9F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3EAE5)),
              ),
              child: Text(
                '${AppLocale.t("Thành phần", "Ingredients")}: ${post['ingredients_text']}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                height: 185,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 64,
                  color: const Color(0xFFF1F5F9),
                  alignment: Alignment.center,
                  child: Text(
                    AppLocale.t('Không tải được ảnh sản phẩm', 'Unable to load product image'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggleLike(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        isLiked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                        color: isLiked ? _dangerRed : const Color(0xFF4B5563),
                        size: 19,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${post['likes_count'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openCommentsSheet(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsRegular.chatCircle,
                        color: Color(0xFF4B5563),
                        size: 19,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${post['comments_count'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (!_isAdmin && post['author_id'] != _userId)
                IconButton(
                  tooltip: AppLocale.t('Báo cáo bài viết', 'Report post'),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.flag,
                    color: Color(0xFF6B7280),
                    size: 18,
                  ),
                  onPressed: () => _openReportDialog(post['id'] as int),
                ),
              if (_isAdmin)
                IconButton(
                  tooltip: isHidden
                      ? AppLocale.t('Hiện lại bài', 'Unhide post')
                      : AppLocale.t('Ẩn bài viết', 'Hide post'),
                  icon: PhosphorIcon(
                    isHidden ? PhosphorIconsBold.eye : PhosphorIconsBold.eyeSlash,
                    color: _brandPurple,
                    size: 18,
                  ),
                  onPressed: () => _deleteOrModeratePost(post, isHidden ? 'unhide' : 'hide'),
                ),
              if (canDelete)
                IconButton(
                  tooltip: AppLocale.t('Xóa bài viết', 'Delete post'),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.trash,
                    color: _dangerRed,
                    size: 18,
                  ),
                  onPressed: () => _deleteOrModeratePost(post, 'delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedBody() {
    final filters = [
      ('ALL', AppLocale.t('Tất cả', 'All')),
      ('GREEN', AppLocale.t('An toàn', 'Safe')),
      ('YELLOW', AppLocale.t('Thận trọng', 'Caution')),
      ('RED', AppLocale.t('Nguy hiểm', 'Danger')),
    ];

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadPosts,
        color: _brandGreen,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, widget.embedded ? 128 : 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocale.t('Cộng đồng', 'Community'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (_isAdmin) ...[
                  NutriVietPressScale(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminModerationScreen(
                              token: _token,
                              currentUserId: _userId,
                            ),
                          ),
                        );
                        await _loadPosts();
                      },
                      child: const NutriVietGlassIconTile(
                        icon: PhosphorIconsFill.shieldCheck,
                        color: _brandPurple,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                NutriVietGlassPillButton(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  label: AppLocale.t('+ Đăng bài', '+ Share'),
                  onPressed: () async {
                    final created = await CommunityFeedScreen.openComposeSheet(
                      context: context,
                      user: widget.user,
                    );
                    if (created && mounted) {
                      await _loadPosts();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 320), _loadPosts);
              },
              style: const TextStyle(color: Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: AppLocale.t(
                  'Tìm sản phẩm, thương hiệu, thành phần...',
                  'Search products, brands, ingredients...',
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: PhosphorIcon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: Color(0xFF6B7280),
                    size: 19,
                  ),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const PhosphorIcon(PhosphorIconsBold.x, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadPosts();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...filters.map((f) {
                    final active = _verdictFilter == f.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (_verdictFilter != f.$1) {
                            setState(() => _verdictFilter = f.$1);
                            _loadPosts();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? _brandGreen
                                : Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: active ? _brandGreen : const Color(0xFFD5E0DA),
                            ),
                          ),
                          child: Text(
                            f.$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_isAdmin)
                    GestureDetector(
                      onTap: () {
                        setState(() => _includeHidden = !_includeHidden);
                        _loadPosts();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _includeHidden
                              ? _brandPurple
                              : Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _includeHidden ? _brandPurple : const Color(0xFFD5E0DA),
                          ),
                        ),
                        child: Text(
                          AppLocale.t('Gồm bài ẩn', 'Include hidden'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _includeHidden ? Colors.white : _brandPurple,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading) ...[
              const NutriVietShimmerBox(height: 156, borderRadius: 22),
              const SizedBox(height: 12),
              const NutriVietShimmerBox(height: 156, borderRadius: 22),
            ] else if (_error != null) ...[
              NutriVietGlassCard(
                cornerRadius: 22,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _dangerRed, fontSize: 13.5),
                    ),
                    const SizedBox(height: 12),
                    NutriVietGlassPillButton(
                      height: 40,
                      label: AppLocale.t('Tải lại', 'Retry'),
                      onPressed: _loadPosts,
                    ),
                  ],
                ),
              ),
            ] else if (_posts.isEmpty) ...[
              NutriVietGlassCard(
                cornerRadius: 22,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const NutriVietGlassIconTile(
                      icon: PhosphorIconsDuotone.sparkle,
                      color: _brandGreen,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocale.t(
                        'Chưa có bài chia sẻ nào.',
                        'No shared products yet.',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocale.t(
                        'Hãy quét một nhãn sản phẩm hoặc bấm "+ Đăng bài" để chia sẻ cùng cộng đồng NutriViet.',
                        'Scan a product label or tap "+ Share" to post to the NutriViet community.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (int i = 0; i < _posts.length; i++) ...[
                _buildPostCard(i),
                if (i < _posts.length - 1) const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _isGuest ? _buildGuestGate(context) : _buildAuthenticatedBody();
    if (widget.embedded) {
      return Material(type: MaterialType.transparency, child: content);
    }
    return NutriVietGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const PhosphorIcon(PhosphorIconsBold.caretLeft, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: content,
      ),
    );
  }
}
