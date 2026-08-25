import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'login_page.dart';
import '../../data/auth_service.dart';
import '../../../home/presentation/pages/main_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _signUp() async {
    final ctx = context;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('الرجاء ملء جميع الحقول')),
        );
      }
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w.-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('صيغة البريد الإلكتروني غير صحيحة')),
        );
      }
      return;
    }

    // Validate password strength
    if (password.length < 6) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
        );
      }
      return;
    }

    // Validate full name length
    if (fullName.length < 2) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('الاسم يجب أن يكون حرفين على الأقل')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final emailTaken = await _authService.isEmailTaken(email);
      if (emailTaken) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('هذا البريد الإلكتروني مسجل بالفعل، يرجى استخدام بريد آخر أو تسجيل الدخول')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final nameTaken = await _authService.isFullNameTaken(fullName);
      if (nameTaken) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('هذا الاسم مستخدم من قبل، يرجى اختيار اسم آخر')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final res = await _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (ctx.mounted) {
        // لو لا يوجد session فهذا يعني أن البريد يحتاج تأكيداً قبل الدخول
        if (res.session == null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الحساب! يرجى تأكيد بريدك الإلكتروني عبر الرسالة التي وصلك'),
            ),
          );
          Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        } else {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('تم إنشاء الحساب بنجاح!')),
          );
          Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        String errorMessage = 'خطأ في إنشاء الحساب';
        String errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('over_email_send_rate_limit') || errorStr.contains('429') || errorStr.contains('rate limit')) {
          errorMessage = 'تم إرسال الكثير من الإيميلات. يرجى الانتظار دقيقة ثم المحاولة مرة أخرى';
        } else if (errorStr.contains('duplicate key') || errorStr.contains('uq_profiles_full_name')) {
          errorMessage = 'هذا الاسم مستخدم من قبل بالفعل، يرجى اختيار اسم آخر';
        } else if (errorStr.contains('email_taken') || errorStr.contains('already registered')) {
          errorMessage = 'هذا البريد الإلكتروني مسجل بالفعل';
        } else if (errorStr.contains('password')) {
          errorMessage = 'كلمة المرور ضعيفة جداً';
        }
        
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (ctx.mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WavyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                FadeInDown(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إنشاء حساب',
                        style: TextStyle(
                          fontSize: 36, 
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ رحلتك الخاصة مع K SHOP',
                        style: TextStyle(
                          fontSize: 16, 
                          color: textColor.withValues(alpha: 0.5)
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 45),
                FadeInLeft(
                  delay: const Duration(milliseconds: 200),
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'الاسم الكامل',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: textColor.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeInLeft(
                  delay: const Duration(milliseconds: 400),
                  child: TextField(
                    controller: _emailController,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined, color: textColor.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeInLeft(
                  delay: const Duration(milliseconds: 600),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: textColor.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: textColor))
                        : ElevatedButton(
                            onPressed: _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('إنشاء حساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                FadeInUp(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('لديك حساب بالفعل؟', style: TextStyle(color: textColor.withValues(alpha: 0.4))),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        child: Text(
                          'سجل دخولك',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
