import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/services/cloudinary_service.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/app_image.dart';

class CategoriesManagementPage extends StatefulWidget {
  const CategoriesManagementPage({super.key});

  @override
  State<CategoriesManagementPage> createState() => _CategoriesManagementPageState();
}

class _CategoriesManagementPageState extends State<CategoriesManagementPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إدارة الأقسام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: WavyBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAddCategorySection(isDark, textColor),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Divider(color: Colors.white10),
              ),
              Expanded(child: _buildCategoriesList(isDark, textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddCategorySection(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FadeInDown(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkGrey : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: textColor.withValues(alpha: 0.05),
                      backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                      child: _selectedImage == null 
                        ? Icon(Icons.add_a_photo_rounded, color: textColor.withValues(alpha: 0.5), size: 30) 
                        : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 15, color: Colors.black),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameArController,
                textAlign: TextAlign.right,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(hintText: 'اسم القسم (عربي)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameEnController,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(hintText: 'اسم القسم (إنجليزي)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.grey) 
                    : const Text('إضافة قسم جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(bool isDark, Color textColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('categories').stream(primaryKey: ['id']).order('created_at'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return Center(
            child: Text('لا توجد أقسام مضافة', style: TextStyle(color: textColor.withValues(alpha: 0.3))),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return FadeInUp(
              delay: Duration(milliseconds: index * 50),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkGrey : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: textColor.withValues(alpha: 0.05)),
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: cat['image_url'] != null
                        ? AppNetworkImage(url: cat['image_url'], width: 50, height: 50, borderRadius: BorderRadius.circular(12))
                        : Container(width: 50, height: 50, color: Colors.grey.withValues(alpha: 0.1), child: const Icon(Icons.category)),
                    ),
                    title: Text(cat['name_ar'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text(cat['name_en'], style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                      onPressed: () => _deleteCategory(cat['id']),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _addCategory() async {
    if (_nameArController.text.isEmpty || _selectedImage == null || _isUploading) return;
    
    setState(() => _isUploading = true);
    try {
      final imageUrl = await _cloudinary.uploadImage(_selectedImage!);
      
      if (imageUrl != null) {
        await _supabase.from('categories').insert({
          'name_ar': _nameArController.text.trim(),
          'name_en': _nameEnController.text.trim(),
          'image_url': imageUrl,
        });
        
        if (mounted) {
          _nameArController.clear();
          _nameEnController.clear();
          setState(() {
            _selectedImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكن الحذف: $e')));
      }
    }
  }
}
