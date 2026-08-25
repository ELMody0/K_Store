import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/services/cloudinary_service.dart';
import '../../../home/presentation/pages/product_details_page.dart';
import 'user_profile_page.dart';
import '../../../../core/utils/role_localization.dart';
import 'package:k_store/core/widgets/app_image.dart';
import 'package:k_store/core/widgets/app_snackbar.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  /// المنتج المرفق (يظهر فوق حقل الكتابة ويُرسل مع أول رسالة)
  final Map<String, dynamic>? attachedProduct;
  /// وضع الدعم: يعرض الطرف الآخر كـ "إدارة المتجر" ويرسل البوت رد تلقائي عند رسالة المستخدم
  final bool supportMode;
  const ChatRoomPage({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.attachedProduct,
    this.supportMode = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CloudinaryService _cloudinary = CloudinaryService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _otherUserData;
  String? _otherUserId;
  Map<String, dynamic>? _attachedProduct;
  bool _isRecording = false;
  bool _isUploadingAudio = false;
  bool _isSending = false; // حارس لمنع الإرسال المتكرر
  String? _currentUserRole; // رتبة المستخدم الحالي (للسماح لغيره بحذف أي رسالة للإشراف)

  // ميزات جديدة
  String? _recordedFilePath; // مسار التسجيل بعد الإيقاف (معاينة قبل الإرسال)
  int? _recordedDuration; // مدة التسجيل بالثواني (للعرض قبل الإرسال)
  String? _playingMessageId; // الرسالة الصوتية قيد التشغيل حالياً
  Duration _playbackPosition = Duration.zero; // موضع التشغيل الحالي
  Duration _playbackDuration = Duration.zero; // مدة الرسالة الصوتية قيد التشغيل
  bool _previewPlaying = false; // تشغيل معاينة التسجيل المحلي
  Map<String, dynamic>? _replyTo; // الرسالة المراد الرد عليها
  bool _otherUserTyping = false; // الطرف الآخر يكتب
  bool _otherUserRecording = false; // الطرف الآخر يسجّل
  bool _markingRead = false; // يمنع تكرار استدعاء تعليم القراءة
  static const String _supportBotName = 'إدارة المتجر';
  static const String _supportAutoReply = 'يرجى الانتظار حتى المراجعة';
  RealtimeChannel? _channel; // قناة الـ realtime للحالة
  Timer? _typingTimer;
  DateTime? _recordingStart; // وقت بدء التسجيل (لحساب المدة)

  @override
  void initState() {
    super.initState();
    _attachedProduct = widget.attachedProduct;
    _fetchOtherUserInfo();
    _loadCurrentUserRole();
    _initRealtime();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _previewPlaying = false;
          _playingMessageId = null;
          _playbackPosition = Duration.zero;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playbackDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playbackPosition = p);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  // ---- Realtime: بث/استقبال حالة الكتابة والتسجيل للطرف الآخر ----
  void _initRealtime() {
    try {
      _channel = _supabase.channel('chat:${widget.chatId}');
      _channel!
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              if (mounted) setState(() => _otherUserTyping = payload['value'] == true);
            },
          )
          .onBroadcast(
            event: 'recording',
            callback: (payload) {
              if (mounted) setState(() => _otherUserRecording = payload['value'] == true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime init error: $e');
    }
  }

  void _notifyTyping() {
    _channel?.sendBroadcastMessage(event: 'typing', payload: {'value': true});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1500), () {
      _channel?.sendBroadcastMessage(event: 'typing', payload: {'value': false});
    });
  }

  // ---- جلب بيانات الطرف الآخر والرتبة ----
  Future<void> _fetchOtherUserInfo() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final chat = await _supabase.from('chats').select('user1_id, user2_id').eq('id', widget.chatId).single();
      final otherUserId = chat['user1_id'] == myId ? chat['user2_id'] : chat['user1_id'];
      _otherUserId = otherUserId;
      final data = await _supabase.from('profiles').select().eq('id', otherUserId).single();
      if (mounted) setState(() => _otherUserData = data);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // في شات الدعم: العميل يشوف "إدارة المتجر" (مخفي الهوية)، أما المالك (المُمثّل) يشوف اسم العميل الحقيقي
  String get _displayOtherName {
    if (widget.supportMode && _currentUserRole != 'owner') return _supportBotName;
    return _otherUserData?['full_name'] ?? widget.otherUserName;
  }

  bool get _maskBotIdentity => widget.supportMode && _currentUserRole != 'owner';

  // ---- حذف الرسالة ----
  Future<void> _deleteMessage(String messageId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: const Text('حذف الرسالة؟', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              try {
                await _supabase.from('messages').delete().eq('id', messageId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الرسالة')));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر حذف الرسالة: $e')));
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---- جلب رتبة المستخدم الحالي ----
  Future<void> _loadCurrentUserRole() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final data = await _supabase.from('profiles').select('role').eq('id', myId).single();
      if (mounted) setState(() => _currentUserRole = data['role']?.toString().toLowerCase());
    } catch (e) {
      debugPrint('Error loading role: $e');
    }
  }

  // ---- الرد على رسالة ----
  void _setReply(Map<String, dynamic> msg) {
    setState(() => _replyTo = msg);
  }

  // ---- قائمة خيارات الرسالة (ضغطة طويلة) مثل الواتس ----
  void _showMessageOptions(Map<String, dynamic> msg, bool canDelete) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkGrey,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white),
              title: const Text('رد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _setReply(msg);
              },
            ),
            if (msg['product_id'] != null)
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.grey),
                title: const Text('مشاركة المنتج', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _forwardProduct(msg['product_id']);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg['id']);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---- مشاركة (تحويل) منتج من شات لشات تاني ----
  Future<void> _forwardProduct(String productId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final myChats = await _supabase
          .from('chats')
          .select('id, user1_id, user2_id, is_support')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');
      final normal = myChats
          .where((c) => c['is_support'] != true && c['id'] != widget.chatId)
          .toList();
      if (normal.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد محادثات أخرى')));
        return;
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.darkGrey,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('شارك المنتج مع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1, color: Colors.white12),
              ...normal.map((chat) {
                final otherId = chat['user1_id'] == myId ? chat['user2_id'] : chat['user1_id'];
                return FutureBuilder<Map<String, dynamic>?>(
                  future: _supabase.from('profiles').select('full_name').eq('id', otherId).maybeSingle(),
                  builder: (c, snap) => ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70),
                    title: Text(snap.data?['full_name'] ?? 'مستخدم', style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await _supabase.from('messages').insert({
                          'chat_id': chat['id'],
                          'sender_id': myId,
                          'product_id': productId,
                          'content': '🛍 منتج مُشارَك',
                        });
                        await _supabase.from('chats').update({
                          'last_message_at': DateTime.now().toIso8601String(),
                          'user1_hidden': false,
                          'user2_hidden': false,
                        }).eq('id', chat['id']);
                        await _notifyOther(chat['id'], '🛍 منتج مُشارَك');
                        if (mounted) AppSnackBar.show(context, 'تمت مشاركة المنتج', success: true);
                      } catch (e) {
                        if (mounted) AppSnackBar.show(context, 'تعذّر المشاركة: $e', error: true);
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  /// يُرسل إشعار FCM للطرف الآخر في محادثة معيّنة (يُستخدم عند مشاركة منتج)
  Future<void> _notifyOther(String chatId, String body) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;
      final chat = await _supabase.from('chats').select('user1_id, user2_id').eq('id', chatId).single();
      final otherId = chat['user1_id'] == myId ? chat['user2_id'] : chat['user1_id'];
      final pref = await _supabase.from('profiles').select('message_notifications').eq('id', otherId).maybeSingle();
      if ((pref?['message_notifications'] ?? true) != true) return;
      await _supabase.functions.invoke(
        'send-push',
        body: {
          'user_id': otherId,
          'sender_id': myId,
          'title': 'منتج مُشارَك',
          'body': body,
          'chat_id': chatId,
        },
      );
    } catch (_) {}
  }

  // ---- تشغيل رسالة صوتية مع إظهار حالة التشغيل ----
  Future<void> _playAudio(String? url, String id) async {
    if (url == null) return;
    try {
      if (_playingMessageId == id) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingMessageId = null);
        return;
      }
      await _audioPlayer.stop();
      if (mounted) setState(() => _playbackPosition = Duration.zero);
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _playingMessageId = id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تشغيل الصوت: $e')));
      }
    }
  }

  // ---- التسجيل الصوتي ----
  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    _recordingStart = DateTime.now();
    setState(() => _isRecording = true);
    _channel?.sendBroadcastMessage(event: 'recording', payload: {'value': true});
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    final duration = _recordingStart != null ? DateTime.now().difference(_recordingStart!).inSeconds : 0;
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
      _recordedDuration = duration;
    });
    _channel?.sendBroadcastMessage(event: 'recording', payload: {'value': false});
  }

  Future<void> _discardRecording() async {
    if (_previewPlaying) {
      await _audioPlayer.stop();
      setState(() => _previewPlaying = false);
    }
    setState(() => _recordedFilePath = null);
  }

  void _togglePreviewPlay() async {
    if (_recordedFilePath == null) return;
    if (_previewPlaying) {
      await _audioPlayer.stop();
      setState(() => _previewPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      setState(() => _previewPlaying = true);
    }
  }

  Future<void> _sendRecordedAudio() async {
    final path = _recordedFilePath;
    if (path == null) return;
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    setState(() => _isUploadingAudio = true);
    try {
      final url = await _cloudinary.uploadFile(File(path), resourceType: CloudinaryResourceType.Video);
      if (url != null) {
        final Map<String, Object?> insertData = {
          'chat_id': widget.chatId,
          'sender_id': currentUserId,
          'content': '🎤 رسالة صوتية',
          'message_type': 'audio',
          'file_url': url,
          'duration': _recordedDuration ?? 0,
        };
        if (_replyTo != null) insertData['reply_to'] = _replyTo!['id'];
        await _supabase.from('messages').insert(insertData);
        _notifyPush('🎤 رسالة صوتية');
        _maybeSendBotAutoReply(currentUserId);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAudio = false;
          _recordedFilePath = null;
          _recordedDuration = null;
          _replyTo = null;
          _previewPlaying = false;
        });
      }
    }
  }

  /// في وضع الدعم: لو العميل بعت رسالة، البوت يرد تلقائياً "يرجى الانتظار حتى المراجعة"
  Future<void> _maybeSendBotAutoReply(String currentUserId) async {
    if (!widget.supportMode) return;
    if (_currentUserRole == 'owner') return; // البوت يرد للعملاء فقط، مش للأونر
    if (_otherUserId == null || currentUserId == _otherUserId) return;

    // الرد التلقائي عبر دالة SECURITY DEFINER (بتتخطى RLS وتبعته كـ "مالك/إدارة المتجر")
    await _supabase.rpc(
      'send_support_auto_reply',
      params: {'p_chat_id': widget.chatId, 'p_content': _supportAutoReply},
    );
  }

  /// للأونر: يفتح محادثة دعم جديدة ومنفصلة مع نفس العميل بدل الرد في شات التواصل العادي
  Future<void> _openSupportChatWithOther() async {
    final myId = _supabase.auth.currentUser?.id;
    final otherId = _otherUserId;
    if (myId == null || otherId == null) return;
    try {
      // ندوّر على محادثة دعم موجودة بين الأونر والعميل (منفصلة عن شات التواصل العادي)
      final myChats = await _supabase
          .from('chats')
          .select('id, user1_id, user2_id, is_support')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');
      final supportChats = myChats.where((c) =>
          c['is_support'] == true &&
          ((c['user1_id'] == myId && c['user2_id'] == otherId) ||
           (c['user1_id'] == otherId && c['user2_id'] == myId))).toList();

      String chatId;
      if (supportChats.isNotEmpty) {
        chatId = supportChats.first['id'];
      } else {
        final created = await _supabase
            .from('chats')
            .insert({'user1_id': myId, 'user2_id': otherId, 'is_support': true})
            .select('id')
            .single();
        chatId = created['id'];
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(chatId: chatId, otherUserName: 'إدارة المتجر', supportMode: true),
          ),
        );
      }
    } catch (e) {
      debugPrint('Open support chat with other error: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    if (_msgController.text.trim().isEmpty) return;

    _isSending = true;

    final text = _msgController.text.trim();
    final attachedProductId = _attachedProduct?['id'];
    final replyToId = _replyTo?['id'];
    _msgController.clear();

    if (mounted) setState(() => _attachedProduct = null);
    if (mounted) setState(() => _replyTo = null);
    _channel?.sendBroadcastMessage(event: 'typing', payload: {'value': false});

    try {
      final Map<String, Object?> insertData = {
        'chat_id': widget.chatId,
        'sender_id': currentUserId,
        'content': text,
        'product_id': attachedProductId,
      };
      if (replyToId != null) insertData['reply_to'] = replyToId;
      await _supabase.from('messages').insert(insertData);

      await _supabase.from('chats').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'user1_hidden': false,
        'user2_hidden': false,
      }).eq('id', widget.chatId);

      _notifyPush(text);
      _maybeSendBotAutoReply(currentUserId);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isSending = false;
    }
  }

  /// يُرسل إشعار FCM للطرف الآخر عبر Edge Function (send-push) بعد حفظ الرسالة
  Future<void> _notifyPush(String body) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;
      final chat = await _supabase
          .from('chats')
          .select('user1_id, user2_id')
          .eq('id', widget.chatId)
          .single();
      final otherId = chat['user1_id'] == myId ? chat['user2_id'] : chat['user1_id'];

      // احترم إعداد المستقبِل: لو قافل إشعارات الرسائل متبعتش
      final pref = await _supabase
          .from('profiles')
          .select('message_notifications')
          .eq('id', otherId)
          .single();
      if ((pref['message_notifications'] ?? true) != true) return;

      await _supabase.functions.invoke(
        'send-push',
        body: {
          'user_id': otherId,
          'sender_id': myId,
          'title': 'رسالة جديدة',
          'body': body,
          'chat_id': widget.chatId,
        },
      );
    } catch (e) {
      debugPrint('Push invoke error: $e');
    }
  }

  // ======================== الواجهة ========================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            if (!widget.supportMode && _otherUserData != null) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userId: _otherUserData!['id'])));
            }
          },
          child: Row(
            children: [
              AppCircleAvatar(
                imageUrl: _maskBotIdentity ? null : _otherUserData?['avatar_url'],
                radius: 18,
                fallbackIcon: _maskBotIdentity ? Icons.support_agent_rounded : Icons.person_rounded,
                backgroundColor: _maskBotIdentity ? Colors.grey.withValues(alpha: 0.2) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayOtherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (!widget.supportMode && _otherUserData != null)
                    Text(roleToArabic(_otherUserData!['role']), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.5)),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentUserRole == 'owner' && !widget.supportMode)
            IconButton(
              icon: const Icon(Icons.support_agent_rounded),
              tooltip: 'فتح محادثة دعم',
              onPressed: _openSupportChatWithOther,
            ),
        ],
      ),
      body: WavyBackground(
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 40),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase.from('messages').stream(primaryKey: ['id']).eq('chat_id', widget.chatId).order('created_at', ascending: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white24));

                  final rawMessages = snapshot.data!;
                  final myId = _supabase.auth.currentUser?.id;
                  // نخفي الرسايل اللي المستخدم الحالي أخفاها عنده بس
                  final visibleMessages = rawMessages.where((m) {
                    final deletedFor = ((m['deleted_for'] as List?)?.map((e) => e.toString()) ?? <String>[]).toList();
                    return !(myId != null && deletedFor.contains(myId));
                  }).toList();
                  final Map<String, Map<String, dynamic>> uniqueMap = {};
                  for (var m in visibleMessages) {
                    uniqueMap[m['id']] = m;
                  }
                  final messages = uniqueMap.values.toList();

                  // تعليم رسائل الطرف الآخر كـ "مقروءة" عند فتح المحادثة (مرة واحدة)
                  if (myId != null) {
                    final hasUnread = messages.any((m) => m['sender_id'] != myId && m['read_at'] == null);
                    if (hasUnread && !_markingRead) {
                      _markingRead = true;
                      _supabase
                          .rpc('mark_messages_read', params: {'p_chat_id': widget.chatId, 'p_reader_id': myId})
                          .then((_) { _markingRead = false; })
                          .catchError((_) { _markingRead = false; });
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id'] == myId;
                      return _buildMessageBubble(msg, isMe, isDark, textColor);
                    },
                  );
                },
              ),
            ),
            if (_otherUserTyping || _otherUserRecording) _buildOtherStatus(),
            _buildInputSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, bool isDark, Color textColor) {
    // رسالة طلب الدعم تُعرض كبوكس أنيق منفصل
    if ((msg['content'] ?? '').toString().startsWith('📌 نوع الطلب')) {
      return _buildSupportRequestCard(msg, isMe);
    }

    // رسالة حالة النظام (مثل حالة البلاغ) تُعرض كبوكس مركزي أنيق
    if ((msg['message_type'] ?? '') == 'status') {
      return _buildStatusMessageCard(msg);
    }

    final isAudio = msg['message_type'] == 'audio';
    final productId = msg['product_id'];
    final replyTo = msg['reply_to'];
    final timeLabel = _formatTime(msg['created_at']);

    // المالك يحذف أي رسالة، وكل مستخدم يحذف رسالته بس
    final canDelete = isMe || _currentUserRole == 'owner';
    // في محادثة الدعم: رسايل المستخدم تظهر بلون تحذيري لإعطاء انطباع "تنبيه"
    final bool isSupportMe = widget.supportMode && isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, canDelete),
        child: FadeIn(
          duration: const Duration(milliseconds: 400),
          child: Container(
            key: ValueKey(msg['id']),
            margin: const EdgeInsets.only(bottom: 16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              gradient: isSupportMe
                  ? const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8C42)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : (isMe
                      ? const LinearGradient(colors: [Color(0xFF333335), Color(0xFF262628)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : const LinearGradient(colors: [Color(0xFF202022), Color(0xFF161618)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isMe ? 22 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 22),
              ),
              border: Border.all(
                color: isSupportMe ? Colors.amberAccent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.06),
                width: isSupportMe ? 1 : 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSupportMe ? Colors.amber.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyTo != null) _buildReplyQuote(replyTo),
                if (productId != null) _buildProductReply(productId, isMe, textColor),
                if (isAudio)
                  _buildAudioContent(msg)
                else
                  Text(
                    msg['content'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.45, fontWeight: FontWeight.w400),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeLabel,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
                    const SizedBox(width: 6),
                    if (isMe)
                      Icon(
                        msg['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: isSupportMe ? Colors.white70 : (msg['read_at'] != null ? Colors.grey.shade300 : Colors.grey.withValues(alpha: 0.4)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- بوكس أنيق لرسالة طلب الدعم ----
  Color _supportAccent(String topic) {
    if (topic.contains('تبليغ') || topic.contains('حظر')) return const Color(0xFFFF7043);
    if (topic.contains('مشكلة')) return const Color(0xFFFFB300);
    if (topic.contains('اقتراح')) return const Color(0xFFFFCA28);
    return const Color(0xFFFFB300);
  }

  IconData _supportIcon(String topic) {
    if (topic.contains('مشكلة')) return Icons.report_problem_outlined;
    if (topic.contains('اقتراح')) return Icons.lightbulb_outline_rounded;
    if (topic.contains('تبليغ') || topic.contains('حظر')) return Icons.flag_outlined;
    return Icons.help_outline_rounded;
  }

  Widget _buildSupportRequestCard(Map<String, dynamic> msg, bool isMe) {
    final raw = (msg['content'] ?? '').toString();
    final topicMatch = RegExp(r'📌 نوع الطلب: (.+)').firstMatch(raw);
    final topic = (topicMatch?.group(1) ?? 'طلب دعم').trim();
    final bodyMatch = RegExp(r'✏️ .+?:\n([\s\S]+)').firstMatch(raw);
    final body = (bodyMatch?.group(1) ?? raw).trim();
    final accent = _supportAccent(topic);
    final timeLabel = _formatTime(msg['created_at']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: FadeIn(
        duration: const Duration(milliseconds: 400),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.22), const Color(0xFF1C1C1E)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Icon(_supportIcon(topic), color: accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('طلب دعم جديد', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          Text(topic, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(14)),
                  child: Text(body, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                ),
                const SizedBox(height: 8),
                Text(timeLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- بوكس رسالة حالة النظام (مثل حالة البلاغ) ----
  Widget _buildStatusMessageCard(Map<String, dynamic> msg) {
    final content = (msg['content'] ?? '').toString();
    final isReviewed = content.contains('تمت مراجعة بلاغك');
    final accent = isReviewed ? Colors.greenAccent : Colors.grey;
    final icon = isReviewed ? Icons.check_circle_outline_rounded : Icons.history_toggle_off_outlined;

    return Align(
      alignment: Alignment.center,
      child: FadeIn(
        duration: const Duration(milliseconds: 400),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  content,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.3),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- محتوى الرسالة الصوتية (زر تشغيل + شريط تقدّم + المدة) مثل الواتس ----
  Widget _buildAudioContent(Map<String, dynamic> msg) {
    final id = msg['id'];
    final isPlaying = _playingMessageId == id;
    final storedSeconds = (msg['duration'] as num?)?.toInt() ?? 0;
    final total = (isPlaying && _playbackDuration.inSeconds > 0) ? _playbackDuration : Duration(seconds: storedSeconds);
    final position = isPlaying ? _playbackPosition : Duration.zero;
    final progress = total.inMilliseconds > 0
        ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _playAudio(msg['file_url'], id),
                child: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill, color: Colors.grey, size: 32),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
            const SizedBox(height: 4),
            Text(_formatDuration(total), style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildReplyQuote(dynamic replyTo) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _supabase.from('messages').select().eq('id', replyTo).single(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final r = snap.data!;
        final txt = r['message_type'] == 'audio' ? '🎤 رسالة صوتية' : (r['content'] ?? '');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(width: 3, height: 30, color: Colors.grey.withValues(alpha: 0.6), margin: const EdgeInsets.only(right: 8)),
              Expanded(
                child: Text(
                  txt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtherStatus() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
        child: _otherUserRecording
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, color: Colors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Text('جارى تسجيل ريكورد', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              )
            : _TypingDots(color: Colors.white70),
      ),
    );
  }

  // ---- شريط إدخال الرسالة ----
  Widget _buildInputSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...? (_attachedProduct != null ? [_buildAttachmentChip(isDark)] : null),
          if (_replyTo != null) _buildReplyChip(isDark),
          if (_isUploadingAudio)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('جاري رفع الصوت...', style: TextStyle(color: Colors.redAccent)),
            )
          else if (_isRecording)
            _buildRecordingBar()
          else if (_recordedFilePath != null)
            _buildVoicePreview(isDark)
          else
            _buildTextRow(isDark),
        ],
      ),
    );
  }

  Widget _buildReplyChip(bool isDark) {
    final r = _replyTo!;
    final txt = r['message_type'] == 'audio' ? '🎤 رسالة صوتية' : (r['content'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
              Container(width: 3, height: 36, color: Colors.grey.withValues(alpha: 0.6), margin: const EdgeInsets.only(right: 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text('الرد على', style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(txt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _replyTo = null),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.redAccent),
          const SizedBox(width: 10),
          const Text('جارى تسجيل ريكورد...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              child: const Icon(Icons.stop, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePreview(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePreviewPlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
              child: Icon(_previewPlaying ? Icons.stop : Icons.play_arrow, color: Colors.black, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('رسالة صوتية جاهزة للإرسال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (_recordedDuration != null && _recordedDuration! > 0)
                  Text(_formatDuration(Duration(seconds: _recordedDuration!)), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _discardRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendRecordedAudio,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: _startRecording,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: const Icon(Icons.mic_none_rounded, color: Colors.white70),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _msgController,
            onChanged: (_) => _notifyTyping(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'اكتب رسالتك...',
              fillColor: Colors.white.withValues(alpha: 0.05),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.black, size: 22),
          ),
        ),
      ],
    );
  }

  /// شريط معاينة المنتج المرفق فوق حقل الكتابة
  Widget _buildAttachmentChip(bool isDark) {
    final prod = _attachedProduct!;
    final images = _productImages(prod);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: images.isNotEmpty
                  ? AppNetworkImage(url: images.first, width: 45, height: 45, borderRadius: BorderRadius.circular(12))
                  : Container(width: 45, height: 45, color: Colors.white10, child: const Icon(Icons.image_outlined, size: 22, color: Colors.white38)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.grey.withValues(alpha: 0.8)),
                    const SizedBox(width: 5),
                    Text('أنت تستفسر عن', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(prod['name_ar'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _attachedProduct = null),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// يجمع كل صور المنتج (الغلاف + المعرض) بدون تكرار
  List<String> _productImages(Map<String, dynamic> prod) {
    final List<String> result = [];
    final thumb = prod['thumbnail_url']?.toString();
    if (thumb != null && thumb.trim().isNotEmpty) result.add(thumb);
    for (final g in (prod['images_urls'] ?? [])) {
      final s = g?.toString() ?? '';
      if (s.isNotEmpty && !result.contains(s)) result.add(s);
    }
    return result;
  }

  // --- UI Helpers for Message ---
  Widget _buildProductReply(String productId, bool isMe, Color textColor) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _supabase.from("products").select().eq('id', productId).single(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: isMe ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        final prod = snapshot.data!;
        final String price = prod['price'].toString().replaceAll(RegExp(r'\.0$'), '');
        final image = _productImages(prod).firstOrNull;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductDetailsPage(product: prod)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null)
                  Stack(
                    children: [
                      AppNetworkImage(url: image, height: 150, width: double.infinity),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)]),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)]),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                const Icon(Icons.sell_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prod['name_ar'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 12, color: Colors.white54),
                                const SizedBox(width: 4),
                                const Text('انقر لمعاينة التفاصيل الكاملة', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(dynamic createdAt) {
    final dt = DateTime.tryParse(createdAt?.toString() ?? '');
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// مؤشر الكتابة: ثلاث نقاط متحركة
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.33;
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            final t = (_controller.value + delay) % 1.0;
            final opacity = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 2 * pi));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: opacity), shape: BoxShape.circle),
            );
          },
        );
      }),
    );
  }
}
