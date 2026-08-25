import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'login_page.dart';
import 'signup_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: WavyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildLogoSection(textColor, isDark),
                const Spacer(flex: 1),
                _buildButtons(isDark),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(Color textColor, bool isDark) {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.shopping_bag_rounded,
              size: 80,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 40),
        FadeInDown(
          duration: const Duration(milliseconds: 600),
          child: Column(
            children: [
              Text(
                'K SHOP',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 3,
                width: 60,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FadeInDown(
          delay: const Duration(milliseconds: 200),
          child: Text(
            'حيث تلتقي الفخامة بالبساطة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: textColor.withValues(alpha: 0.4),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;
    final onAccentColor = isDark ? Colors.black : Colors.white;

    return FadeInUp(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 65,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: onAccentColor,
                elevation: 15,
                shadowColor: accentColor.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'تسجيل الدخول',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.5),
                foregroundColor: accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'إنشاء حساب',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تصميم عصري • تجربة فريدة',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
              fontSize: 12,
              letterSpacing: 2,
            ),
          )
        ],
      ),
    );
  }
}
