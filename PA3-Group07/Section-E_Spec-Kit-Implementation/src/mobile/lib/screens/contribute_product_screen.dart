import 'package:flutter/material.dart';

class ContributeProductScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ContributeProductScreen({super.key, required this.user});

  @override
  State<ContributeProductScreen> createState() => _ContributeProductScreenState();
}

class _ContributeProductScreenState extends State<ContributeProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _barcodeController = TextEditingController(text: '8934567891234');
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _ingredientsController = TextEditingController();

  bool _frontPhotoSelected = false;
  String? _frontPhotoSource;
  bool _ingredientPhotoSelected = false;
  String? _ingredientPhotoSource;
  bool _isSubmitting = false;

  final List<String> _selectedAllergens = [];
  final List<Map<String, String>> _availableAllergens = [
    {'code': 'peanuts', 'name': '🥜 Đậu phộng'},
    {'code': 'seafood', 'name': '🦐 Hải sản'},
    {'code': 'milk', 'name': '🥛 Sữa bò'},
    {'code': 'gluten', 'name': '🌾 Gluten / Lúa mì'},
    {'code': 'eggs', 'name': '🥚 Trứng'},
    {'code': 'soy', 'name': '🌱 Đậu nành'},
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
    final String label = isFront ? 'Mặt Trước Bao Bì' : 'Bảng Thành Phần Dinh Dưỡng';

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
              'Tải Ảnh: $label',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chọn phương thức để đính kèm ảnh sản phẩm rõ nét',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981), size: 22),
              ),
              title: const Text('Chụp ảnh trực tiếp từ Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Mở máy ảnh và chụp trực diện sản phẩm', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  if (isFront) {
                    _frontPhotoSelected = true;
                    _frontPhotoSource = 'Camera (bao_bi_front.jpg)';
                  } else {
                    _ingredientPhotoSelected = true;
                    _ingredientPhotoSource = 'Camera (thanh_phan_ocr.jpg)';
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Đã chụp và đính kèm ảnh $label!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7), size: 22),
              ),
              title: const Text('Chọn ảnh từ Thư viện (Bộ sưu tập)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Tải ảnh đã lưu sẵn trong máy', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  if (isFront) {
                    _frontPhotoSelected = true;
                    _frontPhotoSource = 'Thư viện (gallery_image.jpg)';
                  } else {
                    _ingredientPhotoSelected = true;
                    _ingredientPhotoSource = 'Thư viện (ingredients_scan.jpg)';
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Đã chọn ảnh $label từ bộ sưu tập!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
            if (isSelected)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                ),
                title: const Text('Gỡ bỏ ảnh này', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626), fontSize: 14)),
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
                      content: Text('Đã gỡ ảnh $label'),
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
        const SnackBar(
          content: Text('Vui lòng chọn hoặc chụp ít nhất 1 ảnh bao bì sản phẩm!'),
          backgroundColor: Color(0xFFEF4444),
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
      'author': widget.user['full_name'] ?? 'Tôi (Người dùng)',
      'avatar': '👤',
      'time': 'Vừa xong',
      'product_name': _nameController.text.trim(),
      'brand': _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : 'Đã xác minh bởi cộng đồng',
      'is_warning': _selectedAllergens.isNotEmpty,
      'allergen_badge': _selectedAllergens.isNotEmpty
          ? '🚨 Chứa ${_selectedAllergens.join(", ")}'
          : '✅ An toàn theo nhãn',
      'content': _ingredientsController.text.trim().isNotEmpty
          ? 'Bảng thành phần: ${_ingredientsController.text.trim()}'
          : 'Người dùng đã chia sẻ ảnh bao bì sản phẩm thực tế.',
      'barcode': _barcodeController.text.trim(),
      'likes': 1,
      'is_liked': true,
      'comments': 0,
      'photo_label': _frontPhotoSource ?? _ingredientPhotoSource ?? 'Ảnh bao bì sản phẩm',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Đăng Tải Thành Công!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Sản phẩm "${_nameController.text.trim()}" đã được chia sẻ lên Mạng xã hội cộng đồng NutriViet thành công!\n\nẢnh bao bì và thành phần dinh dưỡng đã sẵn sàng để mọi người cùng xem và cảnh báo.',
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
            child: const Text('Xem Bảng Tin Cộng Đồng'),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF334155), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Đóng Góp Sản Phẩm Mới',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
              // Intro card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.volunteer_activism_rounded, color: Color(0xFF059669), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Đăng tải ảnh thực phẩm lên Mạng xã hội cộng đồng giúp hàng ngàn người dị ứng ăn uống an toàn hơn.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 1: PHOTO UPLOADER
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
                    const Text(
                      'Ảnh Chụp Bao Bì Sản Phẩm (Bắt buộc)*',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chụp rõ nét mặt trước bao bì và phần bảng thành phần / dinh dưỡng.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        // Front Photo Box
                        Expanded(
                          child: InkWell(
                            onTap: () => _showPhotoOptions('front'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 125,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _frontPhotoSelected ? const Color(0xFFD1FAE5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _frontPhotoSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  width: _frontPhotoSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _frontPhotoSelected ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
                                    color: _frontPhotoSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    size: 30,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _frontPhotoSelected ? '✓ Ảnh mặt trước' : '📸 Mặt trước',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _frontPhotoSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _frontPhotoSelected ? (_frontPhotoSource ?? 'Chạm để đổi ảnh') : 'Chạm để chụp/chọn',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _frontPhotoSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Ingredients Photo Box
                        Expanded(
                          child: InkWell(
                            onTap: () => _showPhotoOptions('ingredient'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 125,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _ingredientPhotoSelected ? const Color(0xFFD1FAE5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _ingredientPhotoSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  width: _ingredientPhotoSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _ingredientPhotoSelected ? Icons.check_circle_rounded : Icons.document_scanner_outlined,
                                    color: _ingredientPhotoSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    size: 30,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _ingredientPhotoSelected ? '✓ Ảnh thành phần' : '📸 Bảng thành phần',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _ingredientPhotoSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _ingredientPhotoSelected ? (_ingredientPhotoSource ?? 'Chạm để đổi ảnh') : 'Chạm để chụp/chọn',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _ingredientPhotoSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
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

              // SECTION 2: PRODUCT METADATA
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
                    const Text(
                      'Thông Tin Sản Phẩm',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 14),

                    // Barcode
                    const Text('Mã vạch Barcode / EAN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              prefixIcon: const Icon(Icons.qr_code_rounded, size: 20, color: Color(0xFF94A3B8)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã nhận diện mã vạch 8934567891234'), backgroundColor: Color(0xFF10B981)),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Quét mã'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Product Name
                    const Text('Tên sản phẩm:*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Bánh Que Giòn Cay Ngũ Vị',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
                    ),
                    const SizedBox(height: 12),

                    // Brand Name
                    const Text('Nhà sản xuất / Thương hiệu:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _brandController,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Công ty TNHH VinaFood',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ingredients
                    const Text('Bảng thành phần dinh dưỡng (dán từ OCR hoặc gõ):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _ingredientsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Bột mì, dầu cọ, đường kính, muối ăn, bột ớt, hương tôm...',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Allergen tags
                    const Text('Cảnh báo dị ứng có trong sản phẩm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
                            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF475569),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Đang Tải Lên...' : 'Đăng Tải Sản Phẩm Lên Mạng Xã Hội',
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
