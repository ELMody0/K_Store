import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/features/profile/presentation/pages/chat_room_page.dart';

/// مفتاح التنقل العام لفتح المحادثة من إشعار
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// chat_id معلّق لفتحه بعد وصول التطبيق للشاشة الرئيسية (لو اتفتح من إشعار وهو مغلق)
String? pendingChatId;

void _openChat(String? chatId) {
  if (chatId == null || chatId.isEmpty) return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ChatRoomPage(chatId: chatId, otherUserName: ''),
    ),
  );
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  FlutterLocalNotificationsPlugin().show(
    notification.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'k_store_channel',
        'الرسائل',
        channelDescription: 'إشعارات الرسائل الجديدة',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: message.data['chat_id'],
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // لا نعرض إشعاراً محلياً هنا لأن FCM بيعرض إشعار النظام تلقائياً للرسائل ذات notification
}

class FcmService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await FlutterLocalNotificationsPlugin().initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) => _openChat(response.payload),
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await messaging.getToken();
    if (token != null) await _saveToken(token);

    messaging.onTokenRefresh.listen((token) => _saveToken(token));

    // فورغراوند: عرض إشعار محلي عند وصول رسالة
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // الخلفية: المستخدم ضغط على إشعار النظام
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _openChat(message.data['chat_id']));

    // التطبيق كان مغلقاً واتفتح من الإشعار
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      pendingChatId = initial.data['chat_id'];
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('push_tokens').upsert(
        {'user_id': uid, 'token': token, 'platform': 'android'},
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }
}
