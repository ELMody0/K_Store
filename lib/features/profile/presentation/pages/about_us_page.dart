import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';

const LinearGradient _goldGradient = LinearGradient(
  colors: [Color(0xFFD4AF37), Color(0xFFFFE08A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = info.version);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = textColor.withValues(alpha: 0.6);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('من نحن', style: TextStyle(fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.fromLTRB(25, 110, 25, 40),
          children: [
            _buildHero(textColor, subColor),
            const SizedBox(height: 28),
            _buildVisionCard(textColor, subColor, isDark),
            const SizedBox(height: 24),
            _sectionTitle('مميزات التطبيق', textColor),
            const SizedBox(height: 14),
            _buildFeatures(isDark, textColor, subColor),
            const SizedBox(height: 26),
            _sectionTitle('كيف يعمل', textColor),
            const SizedBox(height: 14),
            _buildSteps(isDark, textColor, subColor),
            const SizedBox(height: 30),
            _buildFooter(textColor, subColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Color textColor, Color subColor) {
    return FadeInDown(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: _goldGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 18),
          const Text('K SHOP', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'منصة تسوّق حديثة تربطك بالبائعين بثقة وأناقة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: subColor, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionCard(Color textColor, Color subColor, bool isDark) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkGrey : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('رؤيتنا', textColor),
            const SizedBox(height: 12),
            Text(
              'نؤمن أن التسوّق يجب أن يكون بسيطاً وآمناً وممتعاً. وُلد K SHOP ليجمع البائعين والمشترين في مكان واحد موثوق، '
              'حيث تلتقي الجودة بالثقة، وتكون تجربتك دائماً في قمة الأناقة والسهولة.',
              style: TextStyle(fontSize: 14.5, color: subColor, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color textColor) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(gradient: _goldGradient, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildFeatures(bool isDark, Color textColor, Color subColor) {
    final items = const [
      (Icons.explore_rounded, 'تصفّح ذكي', 'اكتشف المنتجات والفئات بسهولة وسرعة.'),
      (Icons.chat_bubble_outline_rounded, 'تواصل مباشر', 'محادثة فورية مع البائعين.'),
      (Icons.verified_user_rounded, 'أمان وثقة', 'نظام بلاغات ودعم لحمايتك.'),
      (Icons.person_outline_rounded, 'ملف شخصي', 'تحكّم كامل في بياناتك.'),
    ];
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkGrey : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: textColor.withValues(alpha: 0.08), indent: 16, endIndent: 16),
          itemBuilder: (_, i) {
            final it = items[i];
            return _featureRow(it.$1, it.$2, it.$3, textColor, subColor);
          },
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc, Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(gradient: _goldGradient, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 12.5, color: subColor, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(bool isDark, Color textColor, Color subColor) {
    final steps = const [
      ('أنشئ حسابك', 'عبّئ ملفك الشخصي وابدأ رحلتك.'),
      ('تصفّح وابحث', 'اكتشف المنتجات أو ابحث عمّا تريد.'),
      ('تواصل وأكمل', 'دردش مع البائع وأتمم طلبك.'),
      ('تابع وقيّم', 'تابع حالة طلبك وقيّم تجربتك.'),
    ];
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkGrey : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: List.generate(steps.length, (i) {
            final s = steps[i];
            final isLast = i == steps.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Center(
                      child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 3),
                        Text(s.$2, style: TextStyle(fontSize: 12.5, color: subColor, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFooter(Color textColor, Color subColor) {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Column(
        children: [
          Divider(height: 1, color: textColor.withValues(alpha: 0.1)),
          const SizedBox(height: 18),
          Text('صُنع بكل اهتمام من فريق K SHOP', style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('© 2026 K SHOP. جميع الحقوق محفوظة.', style: TextStyle(fontSize: 11, color: subColor.withValues(alpha: 0.7))),
          const SizedBox(height: 10),
          Text(
            _version.isEmpty ? 'الإصدار ...' : 'الإصدار $_version',
            style: const TextStyle(fontSize: 12, color: Color(0xFFD4AF37), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
