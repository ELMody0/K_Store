import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/pressable_card.dart';
import 'category_products_page.dart';
import 'package:k_store/core/widgets/app_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _categoriesStream = supabase.from('categories').stream(primaryKey: ['id']).order('created_at');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: WavyBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // إعادة بناء الـ stream لسحب أحدث الأقسام من السيرفر
              if (mounted) setState(() => _initStream());
            }, // تحديث يدوي عند السحب للأسفل
            color: textColor,
            backgroundColor: isDark ? AppColors.darkGrey : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                
                // العنوان
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: FadeInLeft(
                    duration: const Duration(milliseconds: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.grey, Color(0xFFBDBDBD)],
                          ).createShader(bounds),
                          child: const Text(
                            'الأقسام',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FadeInRight(
                          delay: const Duration(milliseconds: 600),
                          child: Container(
                            height: 3,
                            width: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Colors.grey, Colors.transparent]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeInRight(
                          delay: const Duration(milliseconds: 800),
                          child: Text(
                            'تسوّق حسب القسم الذي يناسبك',
                            style: TextStyle(color: Colors.grey.withValues(alpha: 0.7), fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // جلب الأقسام
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _categoriesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('خطأ في الاتصال: تأكد من إضافة أقسام', 
                            style: TextStyle(color: textColor.withValues(alpha: 0.5)))
                        );
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: textColor));
                      }
                      
                      final categories = snapshot.data ?? [];
                      if (categories.isEmpty) {
                        return Center(
                          child: FadeIn(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.category_outlined, size: 60, color: textColor.withValues(alpha: 0.1)),
                                const SizedBox(height: 15),
                                Text(
                                  'لا توجد أقسام بعد\nأضف قسماً من لوحة التحكم',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        physics: const BouncingScrollPhysics(),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final name = cat['name_ar'] ?? cat['name_en'] ?? '';
                          return _buildCategoryBanner(context, cat['id'], name, cat['image_url'], index, isDark);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBanner(BuildContext context, String categoryId, String name, String? imageUrl, int index, bool isDark) {
    return FadeInRight(
      delay: Duration(milliseconds: index * 120),
      duration: const Duration(milliseconds: 1000),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 180,
        child: PressableCard(
          radius: 28,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryProductsPage(categoryId: categoryId, categoryName: name))),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Background
              Hero(
                tag: 'cat_$categoryId',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: imageUrl != null
                      ? AppNetworkImage(url: imageUrl, fit: BoxFit.cover)
                      : Container(color: Colors.grey.withValues(alpha: 0.12), child: const Icon(Icons.category, color: Colors.grey, size: 50)),
                ),
              ),
              
              // Dark Overlay for readability
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Glassy Border Effect
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                ),
              ),

              Positioned(
                top: 25,
                right: 25,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                ),
              ),

              // Bottom Decorative Line
              Positioned(
                bottom: 20,
                right: 25,
                child: Container(
                  height: 3,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 10)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


