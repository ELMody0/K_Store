import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة الإشعارات الداخلي (In-App Notifications)
/// تسمع فوراً أي رسائل جديدة تُرسل عبر Supabase Realtime
/// وتحديث عدّاد غير مقروء على تب "الرسائل" في شaclة التصفح السفلي.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// عدد الرسائل غير مقروءة (يُستخدم لعرض Badge على تب الرسائل)
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier(0);

  /// معرف المستخدم الحالي المُRegistered فيه الخدمة
  String? _currentUserId;

  /// معرفات المفاوضات التي يgarب فيها المستخدم الحالي (لتصفية الإشعارات)
  final Set<String> _myChatIds = {};

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _chatsChannel;

  bool _initialized = false;

  /// ته/init الخدمة مع المستخدم الحالي (تستدعي بعد تسجيل الدخول أو عند دخول MainPages)
  Future<void> init() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (_initialized && _currentUserId == user.id) return;

    // لو فيه اشتراكات قديمة (مستخدم مختلف أو بعد تسجيل خروج) نزيلها قبل الاشتراك الجديد
    // لتجنّب تسريب القنوات وتكرار عدّاد غير المقروء
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    if (_chatsChannel != null) {
      _supabase.removeChannel(_chatsChannel!);
      _chatsChannel = null;
    }
    _myChatIds.clear();

    _currentUserId = user.id;
    _initialized = true;
    unreadCountNotifier.value = 0;

    await _loadMyChats();
    _subscribeToChats();
    _subscribeToMessages();
  }

  /// تحميل جميع مفاوضات المستخدم الحالي ل/filter الإشعارات بدقة
  Future<void> _loadMyChats() async {
    try {
      final uid = _currentUserId;
      if (uid == null) return;
      final data = await _supabase
          .from('chats')
          .select('id, user1_id, user2_id')
          .or('user1_id.eq.$uid,user2_id.eq.$uid');
      _myChatIds
        ..clear()
        ..addAll(data.map((c) => c['id'].toString()));
    } catch (e) {
      debugPrint('NotificationService: load chats error: $e');
    }
  }

  /// مراقبة إضافة مفاوضات جديدة (ل addition إلىسيت المفاوضات)
  void _subscribeToChats() {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      _chatsChannel = _supabase.channel('realtime:chats:$uid')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            final c = payload.newRecord;
            if ((c['user1_id']?.toString() == uid) ||
                (c['user2_id']?.toString() == uid)) {
              _myChatIds.add(c['id'].toString());
            }
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('NotificationService: chats subscribe error: $e');
    }
  }

  /// مراقبة وصول رسائل جديدة وزيادة العدّاد إذا كانت الرسالة غير مُرسلة مني
  void _subscribeToMessages() {
    try {
      _messagesChannel = _supabase.channel('realtime:messages')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final msg = payload.newRecord;
            final chatId = msg['chat_id']?.toString();
            final senderId = msg['sender_id']?.toString();

            if (chatId != null &&
                _myChatIds.contains(chatId) &&
                senderId != _currentUserId) {
              unreadCountNotifier.value = unreadCountNotifier.value + 1;
            }
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('NotificationService: messages subscribe error: $e');
    }
  }

  /// تصفير عدّاد غير مقروء (/rest Istدعيها فتح تب الرسائل)
  void clearUnread() {
    unreadCountNotifier.value = 0;
  }

  /// تصفير عدّاد غير مقروء تلقائياً عند مغادرة المفاوضة
  /// ويعلّم رسايل المحادثة كمقروءة في قاعدة البيانات (لو المستخدم مشارك)
  Future<void> resetForChat(String chatId) async {
    final myId = _currentUserId;
    if (myId == null || chatId.isEmpty) return;
    try {
      await _supabase.rpc(
        'mark_messages_read',
        params: {'p_chat_id': chatId, 'p_reader_id': myId},
      );
    } catch (e) {
      debugPrint('NotificationService: mark_messages_read error: $e');
    }
    unreadCountNotifier.value = 0;
  }

  /// تنظيف الموارد عند الخروج
  void dispose() {
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    if (_chatsChannel != null) {
      _supabase.removeChannel(_chatsChannel!);
      _chatsChannel = null;
    }
    // لا نستدعي unreadCountNotifier.dispose() لأنه وحيد (singleton) ويُعاد استخدامه عند تسجيل الدخول مجدداً
    unreadCountNotifier.value = 0;
    _initialized = false;
    _currentUserId = null;
    _myChatIds.clear();
  }
}
