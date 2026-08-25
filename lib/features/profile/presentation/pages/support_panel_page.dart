import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'chat_room_page.dart';

class SupportPanelPage extends StatefulWidget {
  const SupportPanelPage({super.key});

  @override
  State<SupportPanelPage> createState() => _SupportPanelPageState();
}

class _SupportPanelPageState extends State<SupportPanelPage> {
  static const List<Map<String, dynamic>> _topics = [
    {'title': 'استفسار', 'icon': Icons.help_outline_rounded, 'color': Color(0xFFD4AF37), 'label': 'اكتب استفسارك'},
    {'title': 'مشكلة', 'icon': Icons.report_problem_outlined, 'color': Color(0xFFFF8C42), 'label': 'اشرح مشكلتك'},
    {'title': 'اقتراح', 'icon': Icons.lightbulb_outline_rounded, 'color': Color(0xFF2ECC71), 'label': 'اكتب اقتراحك'},
    {'title': 'تبليغ/حظر', 'icon': Icons.flag_outlined, 'color': Color(0xFFE74C3C), 'label': 'اشرح بلاغك'},
  ];

  String? _selectedTopic;
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  String _labelFor(String topic) => _topics.firstWhere((t) => t['title'] == topic, orElse: () => {'label': 'اكتب رسالتك'})['label'] as String;
  Color _colorFor(String topic) => _topics.firstWhere((t) => t['title'] == topic, orElse: () => {'color': Colors.grey})['color'] as Color;
  IconData _iconFor(String topic) => _topics.firstWhere((t) => t['title'] == topic, orElse: () => {'icon': Icons.support_agent_rounded})['icon'] as IconData;

  // رد البوت التلقائي حسب نوع الطلب (أذكى من رسالة ثابتة)
  static const Map<String, String> _autoReplies = {
    'استفسار': 'شكراً لاستفسارك 🤝 سيتم الرد عليك من فريق إدارة المتجر في أقرب وقت ممكن.',
    'مشكلة': 'نأسف لوجود مشكلة 🙏 جاري مراجعة شكواك وسيتم التواصل معك قريباً لحلها.',
    'اقتراح': 'شكراً على اقتراحك القيّم 💡 سيتم دراسته من قبل فريق التطوير.',
    'تبليغ/حظر': 'تم استلام بلاغك 🚩 وجاري مراجعته من قبل الإدارة لاتخاذ الإجراء المناسب.',
  };
  String _autoReplyFor(String topic) => _autoReplies[topic] ?? 'يرجى الانتظار حتى المراجعة، جاري مراجعة طلبك';

  Future<void> _submit() async {
    final topic = _selectedTopic;
    final text = _messageController.text.trim();
    if (topic == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('من فضلك اكتب رسالتك')));
      return;
    }
    setState(() => _sending = true);
    try {
      final supabase = Supabase.instance.client;
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;
      final owner = await supabase.from('profiles').select('id').eq('role', 'owner').limit(1).maybeSingle();
      final ownerId = owner?['id'] ?? myId;

      // ندوّر على محادثة دعم موجودة بين المستخدم وصاحب المتجر (منفصلة تماماً عن شات التواصل العادي)
      final myChats = await supabase
          .from('chats')
          .select('id, user1_id, user2_id, is_support')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');
      final supportChats = myChats.where((c) => c['is_support'] == true).toList();

      String chatId;
      if (supportChats.isNotEmpty) {
        chatId = supportChats.first['id'];
      } else {
        final created = await supabase
            .from('chats')
            .insert({'user1_id': myId, 'user2_id': ownerId, 'is_support': true})
            .select('id')
            .single();
        chatId = created['id'];
      }

      // أرسل نوع الطلب + رسالة المستخدم كأول رسالة في شات الدعم
      final content = '📌 نوع الطلب: $topic\n\n✏️ ${_labelFor(topic)}:\n$text';
      await supabase.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myId,
        'content': content,
      });
      await supabase.from('chats').update({'last_message_at': DateTime.now().toIso8601String()}).eq('id', chatId);

      // رد البوت التلقائي حسب نوع الطلب عبر دالة SECURITY DEFINER
      await supabase.rpc(
        'send_support_auto_reply',
        params: {'p_chat_id': chatId, 'p_content': _autoReplyFor(topic)},
      );

      // لو نوع الطلب "تبليغ/حظر" سجّل بلاغ في جدول reports للأونر يراجعه
      if (topic == 'تبليغ/حظر') {
        await supabase.from('reports').insert({
          'reporter_id': myId,
          'content': text,
          'chat_id': chatId,
          'status': 'pending',
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatRoomPage(chatId: chatId, otherUserName: 'إدارة المتجر', supportMode: true)),
        );
      }
    } catch (e) {
      debugPrint('Open support chat error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('التواصل مع الإدارة', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_selectedTopic != null) {
              setState(() => _selectedTopic = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: WavyBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(25, 120, 25, 25),
          children: [
            if (_selectedTopic == null) ...[
              Text('اختر نوع طلبك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1.1)),
              const SizedBox(height: 10),
              Text('سيتم الرد عليك من فريق إدارة المتجر', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 25),
              ..._topics.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                return FadeInUp(
                  delay: Duration(milliseconds: 100 + i * 80),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkGrey : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: textColor.withValues(alpha: 0.05)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(25),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (t['color'] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(t['icon'] as IconData, color: t['color'] as Color),
                        ),
                        title: Text(t['title'] as String, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withValues(alpha: 0.3)),
                        onTap: () => setState(() => _selectedTopic = t['title'] as String),
                      ),
                    ),
                  ),
                );
              }),
            ] else ...[
              FadeInUp(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkGrey : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: _colorFor(_selectedTopic!).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _colorFor(_selectedTopic!).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_iconFor(_selectedTopic!), color: _colorFor(_selectedTopic!)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('لقد اخترت', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(_selectedTopic!, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('اكتب رسالتك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkGrey : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _messageController,
                  maxLines: 6,
                  minLines: 4,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: _labelFor(_selectedTopic!),
                    hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeInUp(
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorFor(_selectedTopic!),
                    foregroundColor: _selectedTopic == 'استفسار' ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _sending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('إرسال الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
