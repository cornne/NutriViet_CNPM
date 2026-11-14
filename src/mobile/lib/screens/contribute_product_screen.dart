import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../widgets/nutriviet_ui.dart';

class ContributeProductScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ContributeProductScreen({super.key, required this.user});

  @override
  State<ContributeProductScreen> createState() => _ContributeProductScreenState();
}

class _ContributeProductScreenState extends State<ContributeProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _ingredientsController = TextEditingController();

  bool _frontPhotoSelected = false;
  String? _frontPhotoSource;
  bool _ingredientPhotoSelected = false;
  String? _ingredientPhotoSource;
  bool _isSubmitting = false;

  final List<String> _selectedAllergens = [];

  List<Map<String, String>> get _availableAllergens => [
        {'code': 'peanuts', 'name': AppLocale.t('🥜 Đậu phộng', '🥜 Peanuts')},
        {'code': 'seafood', 'name': AppLocale.t('🦐 Hải sản', '🦐 Seafood')},
        {'code': 'milk', 'name': AppLocale.t('🥛 Sữa bò', '🥛 Cow\'s milk')},
        {'code': 'gluten', 'name': AppLocale.t('🌾 Lúa mì / Gluten', '🌾 Wheat / Gluten')},
        {'code': 'eggs', 'name': AppLocale.t('🥚 Trứng', '🥚 Eggs')},
        {'code': 'soy', 'name': AppLocale.t('🌱 Đậu nành', '🌱 Soybeans')},
        {'code': 'tree_nuts', 'name': AppLocale.t('🌰 Hạt cây', '🌰 Tree nuts')},
        {'code': 'sesame', 'name': AppLocale.t('🌿 Mè (Vừng)', '🌿 Sesame')},
      ];

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  void _showPhotoOptions(String type) {
    final bool isFront = type == 'front';
    final bool isSelected = isFront ? _frontPhotoSelected : _ingredientPhotoSelected;
    final String label = isFront
        ? AppLocale.t('Mặt Trước Bao Bì', 'Front Packaging')
        : AppLocale.t('Bảng Thành Phần Dinh Dưỡng', 'Nutrition & Ingredients');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocale.t('Tải Ảnh: $label', 'Upload Photo: $label'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocale.t(
                'Chọn phương thức để đính kèm ảnh sản phẩm rõ nét',
                'Choose a method to attach a clear product photo',
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const NutriVietGlassIconTile(
                icon: PhosphorIconsDuotone.camera,
                color: Color(0xFF14803C),
                size: 38,
              ),
              title: Text(
                AppLocale.t('Chụp ảnh trực tiếp từ máy ảnh', 'Take photo with Camera'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                AppLocale.t(
                  'Mở máy ảnh và chụp trực diện sản phẩm',
                  'Open camera and capture the product directly',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  if (isFront) {
                    _frontPhotoSelected = true;
                    _frontPhotoSource = AppLocale.t(
                      'Máy ảnh (Ảnh mặt trước)',
                      'Camera (Front photo)',
                    );
                  } else {
                    _ingredientPhotoSelected = true;
                    _ingredientPhotoSource = AppLocale.t(
                      'Máy ảnh (Bảng thành phần)',
                      'Camera (Ingredients photo)',
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocale.t(
                        'Đã chụp và đính kèm ảnh $label!',
                        'Captured and attached $label photo!',
                      ),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            ListTile(
              leading: const NutriVietGlassIconTile(
                icon: PhosphorIconsDuotone.images,
                color: Color(0xFF0284C7),
                size: 38,
              ),
              title: Text(
                AppLocale.t('Chọn ảnh từ Thư viện', 'Choose from Photo Library'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                AppLocale.t('Tải ảnh đã lưu sẵn trong máy', 'Select an existing photo from device'),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  if (isFront) {
                    _frontPhotoSelected = true;
                    _frontPhotoSource = AppLocale.t(
                      'Thư viện (Ảnh mặt trước)',
                      'Library (Front photo)',
                    );
                  } else {
                    _ingredientPhotoSelected = true;
                    _ingredientPhotoSource = AppLocale.t(
                      'Thư viện (Bảng thành phần)',
                      'Library (Ingredients photo)',
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocale.t(
                        'Đã chọn ảnh $label từ thư viện!',
                        'Selected $label photo from library!',
                      ),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            if (isSelected)
              ListTile(
                leading: const NutriVietGlassIconTile(
                  icon: PhosphorIconsDuotone.trash,
                  color: Color(0xFFDC2626),
                  size: 38,
                ),
                title: Text(
                  AppLocale.t('Gỡ bỏ ảnh này', 'Remove this photo'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isFront) {
                      _frontPhotoSelected = false;
                      _frontPhotoSource = null;
                    } else {
                      _ingredientPhotoSelected = false;
                      _ingredientPhotoSource = null;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocale.t('Đã gỡ ảnh $label', 'Removed $label photo'),
                      ),
                      backgroundColor: const Color(0xFF64748B),
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_frontPhotoSelected && !_ingredientPhotoSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocale.t(
              'Vui lòng chọn hoặc chụp ít nhất 1 ảnh bao bì sản phẩm!',
              'Please take or select at least 1 product packaging photo!',
            ),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    final newPost = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'author': widget.user['full_name'] ?? AppLocale.t('Tôi (Người dùng)', 'Me (User)'),
      'avatar': '👤',
      'time': AppLocale.t('Vừa xong', 'Just now'),
      'product_name': _nameController.text.trim(),
      'brand': _brandController.text.trim().isNotEmpty
          ? _brandController.text.trim()
          : AppLocale.t('Đã xác minh bởi cộng đồng', 'Community verified'),
      'is_warning': _selectedAllergens.isNotEmpty,
      'allergen_badge': _selectedAllergens.isNotEmpty
          ? AppLocale.t(
              '🚨 Chứa ${_selectedAllergens.join(", ")}',
              '🚨 Contains ${_selectedAllergens.join(", ")}',
            )
          : AppLocale.t('✅ An toàn theo nhãn', '✅ Safe per label'),
      'content': _ingredientsController.text.trim().isNotEmpty
          ? AppLocale.t(
              'Bảng thành phần: ${_ingredientsController.text.trim()}',
              'Ingredients: ${_ingredientsController.text.trim()}',
            )
          : AppLocale.t(
              'Người dùng đã chia sẻ ảnh bao bì sản phẩm thực tế.',
              'User shared real product packaging photos.',
            ),
      'barcode': _barcodeController.text.trim(),
      'likes': 1,
      'is_liked': true,
      'comments': 0,
      'photo_label': _frontPhotoSource ??
          _ingredientPhotoSource ??
          AppLocale.t('Ảnh bao bì sản phẩm', 'Product packaging photo'),
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsFill.checkCircle,
              color: Color(0xFF14803C),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocale.t('Đăng Tải Thành Công!', 'Published Successfully!'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          AppLocale.t(
            'Sản phẩm "${_nameController.text.trim()}" đã được chia sẻ lên Mạng xã hội cộng đồng NutriViet thành công!\n\nẢnh bao bì và thành phần dinh dưỡng đã sẵn sàng để mọi người cùng xem và cảnh báo.',
            'Product "${_nameController.text.trim()}" has been shared to the NutriViet Community Network!\n\nPackaging and ingredient details are now visible to help others.',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, newPost);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocale.t('Xem Bảng Tin Cộng Đồng', 'View Community Feed')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsBold.caretLeft,
            color: Color(0xFF334155),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocale.t('Đóng Góp Sản Phẩm Mới', 'Contribute New Product'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsDuotone.handHeart,
                      color: Color(0xFF14803C),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocale.t(
                          'Đăng tải ảnh thực phẩm lên Mạng xã hội cộng đồng giúp hàng ngàn người dị ứng ăn uống an toàn hơn.',
                          'Sharing food packaging photos with the community helps thousands of people with allergies eat safely.',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF065F46),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Photo Uploader
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.t(
                        'Ảnh Chụp Bao Bì Sản Phẩm (Bắt buộc)*',
                        'Product Packaging Photos (Required)*',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.t(
                        'Chụp rõ nét mặt trước bao bì và phần bảng thành phần / dinh dưỡng.',
                        'Capture a clear photo of the front packaging and the ingredient list.',
                      ),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showPhotoOptions('front'),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 125,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _frontPhotoSelected
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _frontPhotoSelected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFCBD5E1),
                                  width: _frontPhotoSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  PhosphorIcon(
                                    _frontPhotoSelected
                                        ? PhosphorIconsFill.checkCircle
                                        : PhosphorIconsDuotone.camera,
                                    color: _frontPhotoSelected
                                        ? const Color(0xFF14803C)
                                        : const Color(0xFF64748B),
                                    size: 30,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _frontPhotoSelected
                                        ? AppLocale.t('Đã chọn mặt trước', 'Front photo selected')
                                        : AppLocale.t('Ảnh mặt trước', 'Front photo'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _frontPhotoSelected
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _frontPhotoSelected
                                        ? (_frontPhotoSource ??
                                            AppLocale.t('Chạm để đổi ảnh', 'Tap to change'))
                                        : AppLocale.t('Chạm để chụp/chọn', 'Tap to capture/select'),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _frontPhotoSelected
                                          ? const Color(0xFF047857)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: InkWell(
                            onTap: () => _showPhotoOptions('ingredient'),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 125,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _ingredientPhotoSelected
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _ingredientPhotoSelected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFCBD5E1),
                                  width: _ingredientPhotoSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  PhosphorIcon(
                                    _ingredientPhotoSelected
                                        ? PhosphorIconsFill.checkCircle
                                        : PhosphorIconsDuotone.scan,
                                    color: _ingredientPhotoSelected
                                        ? const Color(0xFF14803C)
                                        : const Color(0xFF64748B),
                                    size: 30,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _ingredientPhotoSelected
                                        ? AppLocale.t(
                                            'Đã chọn thành phần',
                                            'Ingredients selected',
                                          )
                                        : AppLocale.t('Bảng thành phần', 'Ingredient list'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _ingredientPhotoSelected
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _ingredientPhotoSelected
                                        ? (_ingredientPhotoSource ??
                                            AppLocale.t('Chạm để đổi ảnh', 'Tap to change'))
                                        : AppLocale.t('Chạm để chụp/chọn', 'Tap to capture/select'),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _ingredientPhotoSelected
                                          ? const Color(0xFF047857)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product Metadata
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.t('Thông Tin Sản Phẩm', 'Product Information'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      AppLocale.t('Mã số mã vạch:', 'Barcode number:'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              prefixIcon: const PhosphorIcon(
                                PhosphorIconsDuotone.qrCode,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocale.t(
                                    'Đã nhận diện mã vạch 8934567891234',
                                    'Detected barcode 8934567891234',
                                  ),
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(AppLocale.t('Quét mã', 'Scan code')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      AppLocale.t('Tên sản phẩm:*', 'Product name:*'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: AppLocale.t(
                          'Ví dụ: Bánh Que Giòn Cay Ngũ Vị',
                          'e.g., Crispy Five-Spice Biscuit Sticks',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? AppLocale.t(
                              'Vui lòng nhập tên sản phẩm',
                              'Please enter the product name',
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      AppLocale.t('Nhà sản xuất / Thương hiệu:', 'Manufacturer / Brand:'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _brandController,
                      decoration: InputDecoration(
                        hintText: AppLocale.t(
                          'Ví dụ: Công ty Thực phẩm Việt',
                          'e.g., VietFood Co., Ltd.',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      AppLocale.t(
                        'Bảng thành phần dinh dưỡng:',
                        'Nutrition & Ingredient list:',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _ingredientsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: AppLocale.t(
                          'Bột mì, dầu cọ, đường kính, muối ăn, bột ớt, hương tôm...',
                          'Wheat flour, palm oil, refined sugar, table salt, chili powder, shrimp flavor...',
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      AppLocale.t(
                        'Cảnh báo dị ứng có trong sản phẩm:',
                        'Allergens present in this product:',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableAllergens.map((item) {
                        final code = item['code']!;
                        final isSelected = _selectedAllergens.contains(code);
                        return FilterChip(
                          label: Text(item['name']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAllergens.add(code);
                              } else {
                                _selectedAllergens.remove(code);
                              }
                            });
                          },
                          selectedColor: const Color(0xFFFEE2E2),
                          checkmarkColor: const Color(0xFFDC2626),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF475569),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const PhosphorIcon(
                        PhosphorIconsDuotone.cloudArrowUp,
                        size: 20,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSubmitting
                      ? AppLocale.t('Đang Tải Lên...', 'Uploading...')
                      : AppLocale.t(
                          'Đăng Tải Sản Phẩm Lên Cộng Đồng',
                          'Publish Product to Community',
                        ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _handleSubmit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
