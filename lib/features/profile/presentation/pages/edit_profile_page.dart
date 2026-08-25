import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/services/cloudinary_service.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/app_image.dart';
import 'package:k_store/core/widgets/app_snackbar.dart';

const LinearGradient _neutralGradient = AppColors.neutralGradient;

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final Function onUpdate;

  const EditProfilePage({super.key, this.profileData, required this.onUpdate});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profileData?['full_name']);
    _phoneController = TextEditingController(text: widget.profileData?['phone']?.toString() ?? '');
    _currentAvatarUrl = widget.profileData?['avatar_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (image != null) {
        setState(() => _isUploading = true);
        final String? imageUrl = await _cloudinaryService.uploadImage(File(image.path));
        if (imageUrl != null) setState(() => _currentAvatarUrl = imageUrl);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'avatar_url': _currentAvatarUrl,
      }).eq('id', userId!);
      
      widget.onUpdate();
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(context, 'تم تحديث البيانات بنجاح', success: true);
      }
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'خطأ في الحفظ: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تعديل البيانات', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent, foregroundColor: textColor, elevation: 0,
      ),
      body: WavyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildAvatarSection(textColor),
                const SizedBox(height: 50),
                _buildTextField('الاسم الكامل', _nameController, textColor, isDark, 1, icon: Icons.person_outline_rounded),
                const SizedBox(height: 25),
                _buildTextField('رقم الموبايل (اختياري)', _phoneController, textColor, isDark, 1,
                    keyboardType: TextInputType.phone, icon: Icons.phone_rounded),
                const SizedBox(height: 60),
                _buildSaveButton(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(Color textColor) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _neutralGradient,
              boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
              child: AppCircleAvatar(
                imageUrl: _currentAvatarUrl,
                radius: 66, backgroundColor: Colors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(_isUploading ? Icons.sync : Icons.camera_alt_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Color textColor, bool isDark, int maxLines,
      {TextInputType? keyboardType, IconData? icon}) {
    return FadeInLeft(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 8),
            child: Text(label.toUpperCase(), style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
              filled: true,
              fillColor: isDark ? AppColors.darkGrey : Colors.grey.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return FadeInUp(
      child: SizedBox(
        width: double.infinity, height: 65,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.black)
              : const Text('حفظ التغييرات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
