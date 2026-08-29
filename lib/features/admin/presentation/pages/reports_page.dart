import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/empty_state.dart';
import 'package:k_store/core/widgets/app_snackbar.dart';
import '../../../profile/presentation/pages/chat_room_page.dart';

class _ReportMeta {
  final String reporterName;
  final Map<String, dynamic>? target; // المستخدم المُبلَّغ عنه
  final String? productName;
  const _ReportMeta({required this.reporterName, this.target, this.productName});
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _reportsStream;
  final Map<String, Future<_ReportMeta>> _metaCache = {};

  @override
  void initState() {
    super.initState();
    _reportsStream = _supabase.from('reports').stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  String _format(DateTime? d) {
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  // تعيين حالة البلاغ فوراً (reviewed / pending) + تحديث رسالة الحالة في الشات
  Future<void> _changeStatus(Map<String, dynamic> r, String newStatus) async {
    final chatId = r['chat_id'];
    final msg = newStatus == 'reviewed'
        ? '✅ تمت مراجعة بلاغك واتخذنا الإجراء المناسب'
        : '⌛ تم إلغاء مراجعة بلاغك';
    try {
      await _supabase.from('reports').update({'status': newStatus}).eq('id', r['id']);
      if (chatId != null) {
        final myId = _supabase.auth.currentUser?.id;
        if (myId != null) {
          final existingMsgId = r['status_message_id'];
          if (existingMsgId != null) {
            await _supabase.from('messages').update({'content': msg}).eq('id', existingMsgId);
          } else {
            final inserted = await _supabase
                .from('messages')
                .insert({'chat_id': chatId, 'sender_id': myId, 'content': msg, 'message_type': 'status'})
                .select('id')
                .single();
            await _supabase.from('reports').update({'status_message_id': inserted['id']}).eq('id', r['id']);
          }
          await _supabase.from('chats').update({'last_message_at': DateTime.now().toIso8601String()}).eq('id', chatId);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر التحديث: $e')));
    }
  }

  Future<_ReportMeta> _loadMeta(Map<String, dynamic> r) async {
    final reporter = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', r['reporter_id'])
        .maybeSingle();
    Map<String, dynamic>? target;
    if (r['reported_user_id'] != null) {
      target = await _supabase
          .from('profiles')
          .select('full_name, is_blocked')
          .eq('id', r['reported_user_id'])
          .maybeSingle();
    }
    Map<String, dynamic>? product;
    if (r['reported_product_id'] != null) {
      product = await _supabase
          .from('products')
          .select('name_ar')
          .eq('id', r['reported_product_id'])
          .maybeSingle();
    }
    return _ReportMeta(
      reporterName: reporter?['full_name'] ?? 'مستخدم',
      target: target,
      productName: product?['name_ar'],
    );
  }

  Future<void> _toggleBlock(String userId, bool block) async {
    try {
      await _supabase.rpc('block_user', params: {'p_user_id': userId, 'p_blocked': block});
      if (mounted) {
        AppSnackBar.show(context, block ? 'تم حظر المستخدم' : 'تم فك الحظر', success: !block);
        setState(() {});
      }
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'تعذّر: $e', error: true);
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: const Text('حذف البلاغ؟', style: TextStyle(color: Colors.white)),
        content: const Text('سيتم حذف البلاغ نهائياً.', style: TextStyle(color: Colors.white70)),
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
      final statusMsgId = r['status_message_id'];
      if (statusMsgId != null) {
        await _supabase.from('messages').delete().eq('id', statusMsgId);
      }
      await _supabase.from('reports').delete().eq('id', r['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف البلاغ')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('البلاغات', style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _reportsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
              final reports = snapshot.data!;
              if (reports.isEmpty) {
                return const EmptyState(icon: Icons.flag_outlined, message: 'لا توجد بلاغات بعد');
              }
              return ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final r = reports[index];
                  final isReviewed = r['status'] == 'reviewed';
                  final chatId = r['chat_id'];
                  return FadeInUp(
                    delay: Duration(milliseconds: index * 80),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkGrey : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: (isReviewed ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.4), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isReviewed ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isReviewed ? 'تمت المراجعة' : 'بانتظار المراجعة',
                                  style: TextStyle(color: isReviewed ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              Expanded(
                                child: FutureBuilder<_ReportMeta>(
                                  future: _metaCache.putIfAbsent(r['id'].toString(), () => _loadMeta(r)),
                                  builder: (context, snap) {
                                    final meta = snap.data;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'بلغ عنه: ${meta?.reporterName ?? 'مستخدم'}',
                                          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        if (meta?.productName != null)
                                          Text(
                                            'المنتج: ${meta!.productName}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        if (meta?.target != null)
                                          Text(
                                            'المستخدم: ${meta!.target!['full_name'] ?? 'مستخدم'}',
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () => _deleteReport(r),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
                            child: Text(r['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: textColor.withValues(alpha: 0.4)),
                                  const SizedBox(width: 6),
                                  Text(_format(DateTime.tryParse(r['created_at'] ?? '')?.toLocal()), style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 11)),
                                ],
                              ),
                              if (r['reported_user_id'] != null)
                                FutureBuilder<_ReportMeta>(
                                  future: _metaCache.putIfAbsent(r['id'].toString(), () => _loadMeta(r)),
                                  builder: (context, snap) {
                                    final target = snap.data?.target;
                                    if (target == null) return const SizedBox();
                                    final blocked = target['is_blocked'] == true;
                                    return TextButton.icon(
                                      onPressed: () => _toggleBlock(r['reported_user_id'], !blocked),
                                      icon: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 16, color: Colors.redAccent),
                                      label: Text(blocked ? 'فك الحظر' : 'حظر',
                                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              if (chatId != null)
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ChatRoomPage(chatId: chatId, otherUserName: 'إدارة المتجر', supportMode: true)),
                                  ),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('فتح المحادثة'),
                                ),
                              TextButton(
                                onPressed: () => _changeStatus(r, 'reviewed'),
                                child: const Text('تمت المراجعة', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900)),
                              ),
                              TextButton(
                                onPressed: () => _changeStatus(r, 'pending'),
                                child: const Text('إلغاء المراجعة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900)),
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
          ),
        ),
      ),
    );
  }
}
