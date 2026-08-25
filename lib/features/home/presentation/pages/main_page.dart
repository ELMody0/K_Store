import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/core/services/notification_service.dart';
import 'package:k_store/core/services/fcm_service.dart';
import 'home_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../profile/presentation/pages/chat_room_page.dart';
import '../../../profile/presentation/pages/app_updates_page.dart';
import '../../../chat/presentation/pages/chat_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  int _previousIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const AppUpdatesPage(),
    const ChatPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService().init();

    // لو التطبيق اتفتح من إشعار وهو مغلق، افتح المحادثة بعد وصول الشاشة الرئيسية
    if (pendingChatId != null) {
      final chatId = pendingChatId!;
      pendingChatId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatRoomPage(chatId: chatId, otherUserName: '')),
          );
        }
      });
    }
  }

  void _onTap(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
    if (index == 2) NotificationService().clearUnread();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calm = isDark ? Colors.white : Colors.black;
    final unselected = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.4);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // الصفحة الحالية مع انتقال فخم (slide + fade) عند التنقل
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 480),
            switchInCurve: Curves.easeOutQuint,
            switchOutCurve: Curves.easeInQuint,
            transitionBuilder: (child, animation) {
              final dir = _previousIndex <= _selectedIndex ? 1.0 : -1.0;
              return SlideTransition(
                position: Tween<Offset>(begin: Offset(0.1 * dir, 0), end: Offset.zero).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),

          // شريط التنقل السفلي بستايل iOS (زجاجي عائم مدوّر)
          Positioned(
            bottom: 34,
            left: 18,
            right: 18,
            child: FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 74,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'الرئيسية', calm, unselected),
                        _buildNavItem(1, Icons.new_releases_outlined, Icons.new_releases_rounded, 'تحديثات', calm, unselected),
                        _buildNavItem(2, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'الرسائل', calm, unselected, showBadge: true),
                        _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'حسابي', calm, unselected),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    Color calm,
    Color unselected, {
    bool showBadge = false,
  }) {
    final bool isSelected = _selectedIndex == index;

    final Widget iconChild = showBadge
        ? ValueListenableBuilder<int>(
            valueListenable: NotificationService().unreadCountNotifier,
            builder: (context, count, child) {
              final Icon baseIcon = Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected ? calm : unselected,
                size: 24,
              );
              if (count <= 0) return baseIcon;
              return Badge(
                backgroundColor: Colors.redAccent,
                textColor: Colors.white,
                offset: Offset(-_badgeOffsetX(count), -4),
                label: count > 99 ? const Text('99+') : Text('$count'),
                child: baseIcon,
              );
            },
          )
        : Icon(
            isSelected ? filledIcon : outlineIcon,
            color: isSelected ? calm : unselected,
            size: 24,
          );

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // الأيقونة بتموّج (scale) عند التحديد
            AnimatedScale(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              scale: isSelected ? 1.2 : 1.0,
              child: iconChild,
            ),
            const SizedBox(height: 5),
            // الـ label ظاهر دايماً كبستايل iOS
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? calm : unselected,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            // مؤشر فخم بيتحرك/بينمو تحت التبويب النشط
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutQuint,
              height: 3,
              width: isSelected ? 22 : 0,
              decoration: BoxDecoration(
                color: calm,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [BoxShadow(color: calm.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _badgeOffsetX(int count) {
    final int len = count > 99 ? 3 : (count >= 10 ? 2 : 1);
    return len * 6.0;
  }
}
