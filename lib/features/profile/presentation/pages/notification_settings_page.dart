import 'package:flutter/material.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/notification_toggles.dart';

const LinearGradient _goldGradient = LinearGradient(
  colors: [Color(0xFFD4AF37), Color(0xFFFFE08A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(25, 110, 25, 25),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: _goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'الإشعارات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1.1),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'تحكّم في أنواع الإشعارات التي تصل إليك',
                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkGrey : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Material(color: Colors.transparent, child: const NotificationToggles()),
            ),
          ],
        ),
      ),
    );
  }
}
