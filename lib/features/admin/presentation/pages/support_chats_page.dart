import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/empty_state.dart';
import 'package:k_store/core/widgets/app_snackbar.dart';
import '../../../profile/presentation/pages/chat_room_page.dart';

class SupportChatsPage extends StatefulWidget {
  const SupportChatsPage({super.key});

  @override
  State<SupportChatsPage> createState() => _SupportChatsPageState();
}

class _SupportChatsPageState extends State<SupportChatsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final chats = await _supabase
          .from('chats')
          .select('id, user1_id, user2_id, last_message_at')
          .eq('is_support', true)
          .order('last_message_at', ascending: false);
      final result = <Map<String, dynamic>>[];
      for (final chat in chats) {
        final otherId = chat['user1_id'] == myId ? chat['user2_id'] : chat['user1_id'];
        String name = 'مستخدم';
        try {
          final p = await _supabase.from('profiles').select('full_name').eq('id', otherId).maybeSingle();
          if (p != null && p['full_name'] != null) name = p['full_name'];
        } catch (_) {}
        result.add({...chat, 'other_name': name});
      }
      if (mounted) setState(() => _chats = result);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'خطأ: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> chat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: const Text('حذف محادثة الدعم؟', style: TextStyle(color: Colors.white)),
        content: const Text('سيتم حذف المحادثة ورسائلها نهائياً.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supabase.from('messages').delete().eq('chat_id', chat['id']);
      await _supabase.from('chats').delete().eq('id', chat['id']);
      // إزالة العنصر فوراً من القائمة + إعادة تحميل للتأكيد
      setState(() => _chats.removeWhere((c) => c['id'] == chat['id']));
      if (mounted) AppSnackBar.show(context, 'تم حذف محادثة الدعم', success: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'تعذّر الحذف: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('محادثات الدعم', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WavyBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.grey))
            : _chats.isEmpty
                ? const EmptyState(icon: Icons.support_agent_rounded, message: 'لا توجد محادثات دعم بعد')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
                    itemCount: _chats.length,
                    itemBuilder: (context, i) {
                      final chat = _chats[i];
                      return FadeInUp(
                        delay: Duration(milliseconds: i * 50),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkGrey : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6)),
                                ],
                              ),
                          child: Material(
                            color: Colors.transparent,
                            clipBehavior: Clip.antiAlias,
                            borderRadius: BorderRadius.circular(20),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.neutralGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.support_agent_rounded, color: Colors.white),
                              ),
                              title: Text(chat['other_name'] ?? 'مستخدم', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              subtitle: const Text('محادثة دعم', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    onPressed: () => _confirmDelete(chat),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withValues(alpha: 0.3)),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomPage(
                                    chatId: chat['id'],
                                    otherUserName: 'إدارة المتجر',
                                    supportMode: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
