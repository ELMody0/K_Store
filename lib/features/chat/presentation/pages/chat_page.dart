import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import '../../../profile/presentation/pages/chat_room_page.dart';
import 'package:k_store/core/widgets/app_image.dart';
import 'package:k_store/core/widgets/empty_state.dart';
import 'package:k_store/core/widgets/app_snackbar.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  void _showChatOptions(BuildContext context, Map<String, dynamic> chat, SupabaseClient supabase, String name) {
    final myId = supabase.auth.currentUser?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('محادثة مع $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1, color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('مسح المحادثة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('ستُخفى عنك فقط، الطرف الآخر سيبقى يراها', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () async {
                Navigator.pop(c);
                if (myId == null) return;
                try {
                  // مسح عندي فقط: نخفي المحادثة عن المستخدم الحالي، الطرف التاني يفضل شايفها
                  final col = chat['user1_id'] == myId ? 'user1_hidden' : 'user2_hidden';
                  await supabase.from('chats').update({col: true}).eq('id', chat['id']);
                  // نخفي رسايل المحادثة عن المستخدم الحالي بس (الطرف التاني يشوفها زي ما هي)
                  await supabase.rpc('hide_chat_messages', params: {'p_chat_id': chat['id'], 'p_user_id': myId});
                  if (context.mounted) AppSnackBar.show(context, 'تم مسح المحادثة عندك', success: true);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر مسح المحادثة: $e')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.white70),
              title: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.pop(c),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myId = currentUser.id;

    return FutureBuilder<String?>(
      future: Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', myId)
          .single()
          .then((d) => d['role']?.toString()),
      builder: (context, roleSnap) {
        final myRole = roleSnap.data;
        final supabase = Supabase.instance.client;

        return Scaffold(
          body: WavyBackground(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text('الرسائل', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 25),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase.from('chats').stream(primaryKey: ['id']).order('last_message_at', ascending: false),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                        final chats = snapshot.data!.where((chat) {
                          if (chat['user1_id'] != myId && chat['user2_id'] != myId) return false;
                          // الأونر: شاتات الدعم تظهر في "محادثات الدعم" بس، مش في الرسايل العادية
                          if (myRole == 'owner' && chat['is_support'] == true) return false;
                          // مخفي عند المستخدم الحالي؟ (مسح عندي فقط)
                          final hiddenForMe = chat['user1_id'] == myId
                              ? (chat['user1_hidden'] == true)
                              : (chat['user2_hidden'] == true);
                          if (hiddenForMe) return false;
                          return true;
                        }).toList();

                        if (chats.isEmpty) {
                          return const EmptyState(icon: Icons.chat_bubble_outline_rounded, message: 'لا توجد محادثات بعد');
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            final isSupport = chat['is_support'] == true;
                            final mask = isSupport && myRole != 'owner';
                            final otherId = chat['user1_id'] == myId ? chat['user2_id'] : chat['user1_id'];

                            // شات الدعم يظهر للعميل كـ "إدارة المتجر" (مخفي الهوية)
                            if (mask) {
                              return FadeInUp(
                                delay: Duration(milliseconds: index * 100),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 15),
                                  child: Material(
                                    color: isDark ? AppColors.darkGrey : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => ChatRoomPage(chatId: chat['id'], otherUserName: 'إدارة المتجر', supportMode: true)),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                                        child: const Icon(Icons.support_agent_rounded, color: Colors.grey),
                                      ),
                                      title: Text('إدارة المتجر', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                      subtitle: const Text('محادثة دعم', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return FutureBuilder(
                              future: supabase.from('profiles').select().eq('id', otherId).single(),
                              builder: (context, profileSnapshot) {
                                if (!profileSnapshot.hasData) return const SizedBox();
                                final otherUser = profileSnapshot.data!;
                                final name = otherUser['full_name'] ?? 'مستخدم';
                                return FadeInUp(
                                  delay: Duration(milliseconds: index * 100),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 15),
                                    child: Material(
                                      color: isDark ? AppColors.darkGrey : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => ChatRoomPage(chatId: chat['id'], otherUserName: name, supportMode: isSupport)),
                                          ),
                                          onLongPress: () => _showChatOptions(context, chat, supabase, name),
                                        leading: AppCircleAvatar(
                                          imageUrl: otherUser['avatar_url'],
                                          radius: 20,
                                          backgroundColor: Colors.black,
                                        ),
                                        title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                        subtitle: const Text('اضغط لفتح المحادثة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
