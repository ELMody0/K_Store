import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'chat_room_page.dart';
import '../../../../core/utils/role_localization.dart';
import 'package:k_store/core/widgets/app_image.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WavyBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SizedBox(
                  width: double.infinity, // لضمان التوسيط الكامل
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // توسيط العناصر داخلياً
                    children: [
                      const SizedBox(height: 60),
                      _buildHeader(textColor, isDark),
                      const SizedBox(height: 20),
                      _buildPhoneSection(textColor, isDark),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
        ),
      ),
      bottomNavigationBar: _buildBottomContactButton(textColor, isDark),
    );
  }

  /// عرض رقم الموبايل (اختياري) لباقي المستخدمين — يظهر فقط لو المستخدم أضافه
  Widget _buildPhoneSection(Color textColor, bool isDark) {
    final phone = _userData?['phone']?.toString().trim();
    if (phone == null || phone.isEmpty) return const SizedBox();
    return FadeInUp(
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: phone));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الهاتف')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkGrey : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_rounded, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(phone, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, bool isDark) {
    final avatarUrl = _userData?['avatar_url'];
    final name = _userData?['full_name'] ?? 'مستخدم K SHOP';
    final role = roleToArabic(_userData?['role']);

    return FadeInDown(
      child: Column(
        children: [
          AppCircleAvatar(
            imageUrl: avatarUrl,
            radius: 65,
            backgroundColor: isDark ? AppColors.darkGrey : Colors.white,
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (_userData?['is_verified'] == true) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, color: Color(0xFF1DA1F2), size: 26),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: textColor.withValues(alpha: 0.6),
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// إنشاء محادثة مع صاحب البروفايل (نفس آلية زر "تواصل مع البائع")
  Future<void> _contactUser() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null || myId == widget.userId) return;

    try {
      final ids = [myId, widget.userId]..sort();
      // ندوّر على محادثة عادية موجودة بين الزوجين (في Dart لتفادي غموض .or/.and)
      final myChats = await _supabase
          .from('chats')
          .select('id, user1_id, user2_id, user1_hidden, user2_hidden')
          .eq('is_support', false)
          .or('user1_id.eq.$myId,user2_id.eq.$myId');
      final pairChats = myChats.where((c) =>
          (c['user1_id'] == ids[0] && c['user2_id'] == ids[1]) ||
          (c['user1_id'] == ids[1] && c['user2_id'] == ids[0])).toList();
      final existing = pairChats.isNotEmpty ? pairChats.first : null;

      String chatId;
      if (existing != null) {
        // نفتح نفس المحادثة ونفك إخفاءها عنده (الرسايل القديمة متخفية عنه من قبل)
        chatId = existing['id'];
        final hiddenCol = ids[0] == myId ? 'user1_hidden' : 'user2_hidden';
        await _supabase.from('chats').update({hiddenCol: false}).eq('id', chatId);
      } else {
        final created = await _supabase
            .from('chats')
            .insert({
              'user1_id': ids[0],
              'user2_id': ids[1],
              'is_support': false,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        chatId = created['id'];
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomPage(
            chatId: chatId,
            otherUserName: _userData?['full_name'] ?? 'مستخدم',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  /// زر التواصل في أسفل الشاشة — مخفي في بروفايلك الشخصي
  Widget? _buildBottomContactButton(Color textColor, bool isDark) {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null || myId == widget.userId) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton.icon(
          onPressed: _contactUser,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text(
            'تواصل الآن',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: textColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
