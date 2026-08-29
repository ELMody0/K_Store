import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/services/cloudinary_service.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/app_image.dart';
import '../../../home/presentation/pages/product_details_page.dart';

class ProductsManagementPage extends StatefulWidget {
  const ProductsManagementPage({super.key});

  @override
  State<ProductsManagementPage> createState() => _ProductsManagementPageState();
}

class _ProductsManagementPageState extends State<ProductsManagementPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  final _nameArController = TextEditingController();
  final _descriptionArController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  
  String? _selectedCategoryId;
  File? _thumbnailImage;
  List<File> _galleryImages = [];
  bool _isUploading = false;
  String? _currentUserId;
  bool _isOwnerRole = false;
  late final Stream<List<Map<String, dynamic>>> _categoriesStream;
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _categoriesStream = _supabase.from('categories').stream(primaryKey: ['id']);
    _productsStream = _supabase.from('products').stream(primaryKey: ['id']).order('created_at');
  }

  Future<void> _loadRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _currentUserId = user.id;
    final data = await _supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (mounted) setState(() => _isOwnerRole = (data?['role']?.toString().toLowerCase() == 'owner'));
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _descriptionArController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) setState(() => _thumbnailImage = File(image.path));
  }

  Future<void> _pickGalleryImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 50);
    if (images.isNotEmpty) {
      setState(() => _galleryImages.addAll(images.map((img) => File(img.path))));
    }
  }

  Future<void> _addProduct() async {
    if (_isUploading) return; // حماية ضد الضغط المتكرر

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
      return;
    }

    if (_nameArController.text.isEmpty || _thumbnailImage == null || _selectedCategoryId == null || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار صورة غلاف وتعبئة البيانات')));
      return;
    }
    
    setState(() => _isUploading = true);
    try {
      final price = double.tryParse(_priceController.text);
      if (price == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال سعر صحيح بالأرقام')));
        return;
      }
      // 1. رفع صورة الغلاف
      final thumbnailUrl = await _cloudinary.uploadImage(_thumbnailImage!);

      // 2. رفع صور المعرض
      List<String> galleryUrls = [];
      for (var file in _galleryImages) {
        final url = await _cloudinary.uploadImage(file);
        if (url != null) galleryUrls.add(url);
      }
      
      // 3. حفظ المنتج وجلب البيانات المضافة
      final insertedProduct = await _supabase.from('products').insert({
        'category_id': _selectedCategoryId,
        'name_ar': _nameArController.text.trim(),
        'description_ar': _descriptionArController.text.trim(),
        'price': price,
        'stock_quantity': int.tryParse(_stockController.text) ?? 0,
        'thumbnail_url': thumbnailUrl,
        'images_urls': galleryUrls,
        'user_id': currentUser.id,
      }).select().single();

      // إشعار broadcast لكل المستخدمين (ما عدا الناشر) عن المنتج الجديد
      try {
        final myId = currentUser.id;
        await _supabase.functions.invoke(
          'send-push',
          body: {
            'broadcast': true,
            'exclude_user_id': myId,
            'caller_id': myId,
            'sender_id': myId,
            'title': 'منتج جديد',
            'body': insertedProduct['name_ar'] ?? 'تمت إضافة منتج جديد',
            'image': thumbnailUrl,
            'chat_id': '',
          },
        );
      } catch (e) {
        debugPrint('Product push invoke error: $e');
      }

      if (mounted) {
        _nameArController.clear();
        _descriptionArController.clear();
        _priceController.clear();
        _stockController.clear();
        setState(() {
          _thumbnailImage = null;
          _galleryImages = [];
          _selectedCategoryId = null;
        });

        // 4. التحويل التلقائي لصفحة تفاصيل المنتج
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailsPage(product: insertedProduct)),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة المنتج بنجاح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إدارة المنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: WavyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildAddProductSection(isDark, textColor),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 25), child: Divider(color: Colors.white10)),
                _buildProductsList(isDark, textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddProductSection(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FadeInDown(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkGrey : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15)],
          ),
          child: Column(
              children: [
                Text('صورة الغلاف (الرئيسية)', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickThumbnail,
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      image: _thumbnailImage != null ? DecorationImage(image: FileImage(_thumbnailImage!), fit: BoxFit.cover) : null,
                    ),
                    child: _thumbnailImage == null ? Icon(Icons.add_a_photo_rounded, color: textColor.withValues(alpha: 0.3)) : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text('صور إضافية للمعرض', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _galleryImages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _galleryImages.length) {
                        return GestureDetector(
                          onTap: _pickGalleryImages,
                          child: Container(width: 60, decoration: BoxDecoration(color: textColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add)),
                        );
                      }
                      return Container(
                        width: 60, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: FileImage(_galleryImages[index]), fit: BoxFit.cover)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _categoriesStream,
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      dropdownColor: isDark ? AppColors.darkGrey : Colors.white,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(hintText: 'اختر القسم'),
                      items: categories.map((cat) => DropdownMenuItem(value: cat['id'].toString(), child: Text(cat['name_ar']))).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(controller: _nameArController, textAlign: TextAlign.right, style: TextStyle(color: textColor), decoration: const InputDecoration(hintText: 'اسم المنتج')),
                const SizedBox(height: 10),
                TextField(controller: _descriptionArController, textAlign: TextAlign.right, maxLines: 2, style: TextStyle(color: textColor), decoration: const InputDecoration(hintText: 'وصف المنتج')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _priceController, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: const InputDecoration(hintText: 'السعر'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _stockController, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: const InputDecoration(hintText: 'الكمية'))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _addProduct,
                    child: _isUploading ? const CircularProgressIndicator(color: Colors.grey) : const Text('نشر المنتج الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildProductsList(bool isDark, Color textColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = snapshot.data!;
        // المالك يشوف كل المنتجات، وصاحب كل منتج يشوف منتجه بس
        final visible = _isOwnerRole
            ? products
            : products.where((p) => p['user_id'] == _currentUserId).toList();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final prod = visible[index];
            return FadeInUp(
              delay: Duration(milliseconds: index * 50),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(color: isDark ? AppColors.darkGrey : Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: prod['thumbnail_url'] != null ? AppNetworkImage(url: prod['thumbnail_url'], width: 50, height: 50, borderRadius: BorderRadius.circular(10)) : const Icon(Icons.image),
                    ),
                    title: Text(prod['name_ar'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('${prod['price']}', style: TextStyle(color: textColor.withValues(alpha: 0.9), fontWeight: FontWeight.bold)),
                    trailing: (_isOwnerRole || prod['user_id'] == _currentUserId)
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: isDark ? AppColors.darkGrey : Colors.white,
                                  title: const Text('حذف المنتج؟'),
                                  content: const Text('هل أنت متأكد من حذف هذا المنتج؟ لا يمكن التراجع.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _supabase.from('products').delete().eq('id', prod['id']);
                              }
                            },
                          )
                        : null,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
