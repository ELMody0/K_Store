import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// زرّي التحكم في إشعارات الرسائل والمنتجات — يُستخدم في صفحة الإعدادات
/// وفي بانل "الإشعارات" المستقل.
class NotificationToggles extends StatefulWidget {
  const NotificationToggles({super.key});

  @override
  State<NotificationToggles> createState() => _NotificationTogglesState();
}

class _NotificationTogglesState extends State<NotificationToggles> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _messageNotifications = true;
  bool _productNotifications = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('profiles')
          .select('message_notifications, product_notifications')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _messageNotifications = data['message_notifications'] ?? true;
          _productNotifications = data['product_notifications'] ?? true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Load notification preference error: $e');
    }
  }

  Future<void> _updatePreference(String column, bool value) async {
    if (column == 'message_notifications') {
      setState(() => _messageNotifications = value);
    } else {
      setState(() => _productNotifications = value);
    }
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('profiles').update({column: value}).eq('id', userId);
    } catch (e) {
      debugPrint('Update notification preference error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        SwitchListTile(
          title: Text('إشعارات الرسائل', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          subtitle: Text(
            _loading ? 'جارٍ التحميل...' : (_messageNotifications ? 'مُفعّلة' : 'مُعطّلة'),
            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
          ),
          value: _messageNotifications,
          activeThumbColor: const Color(0xFFD4AF37),
          onChanged: _loading ? null : (v) => _updatePreference('message_notifications', v),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          title: Text('إشعارات المنتجات الجديدة', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          subtitle: Text(
            _loading ? 'جارٍ التحميل...' : (_productNotifications ? 'مُفعّلة' : 'مُعطّلة'),
            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
          ),
          value: _productNotifications,
          activeThumbColor: const Color(0xFFD4AF37),
          onChanged: _loading ? null : (v) => _updatePreference('product_notifications', v),
        ),
      ],
    );
  }
}
