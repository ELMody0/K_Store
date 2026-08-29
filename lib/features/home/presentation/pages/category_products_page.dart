import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/widgets/pressable_card.dart';
import '../../../admin/presentation/pages/products_management_page.dart';
import 'product_details_page.dart';
import 'package:k_store/core/widgets/app_image.dart';

class CategoryProductsPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _userRole;
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _productsStream = _supabase.from('products').stream(primaryKey: ['id']).eq('category_id', widget.categoryId).order('created_at');
  }

  Future<void> _getUserRole() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      final data = await _supabase.from('profiles').select('role').eq('id', userId).maybeSingle();
      if (mounted) setState(() => _userRole = data?['role']?.toString().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    bool canPost = ['owner', 'customer'].contains(_userRole);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
      ),
      floatingActionButton: canPost
          ? ZoomIn(
              child: FloatingActionButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsManagementPage())),
                backgroundColor: textColor,
                child: Icon(Icons.add_rounded, color: isDark ? Colors.black : Colors.white, size: 30),
              ),
            )
          : null,
      body: WavyBackground(
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
              final products = snapshot.data ?? [];
              if (products.isEmpty) return const Center(child: Text('لا توجد منتجات بعد', style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final prod = products[index];
                  return FadeInRight(
                    delay: Duration(milliseconds: index * 100),
                    duration: const Duration(milliseconds: 900),
                    child: _buildProductBanner(context, prod, isDark),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProductBanner(BuildContext context, Map<String, dynamic> prod, bool isDark) {
    final String? imageUrl = prod['thumbnail_url'];
    final String name = prod['name_ar'] ?? '';
    final String price = (prod['price']?.toString() ?? '').replaceAll(RegExp(r'\.0$'), '');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 170, // حجم مناسب وواضح
      child: PressableCard(
        radius: 28,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsPage(product: prod))),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image Background
            Hero(
              tag: 'prod_${prod['id']}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: imageUrl != null
                    ? AppNetworkImage(url: imageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey.withValues(alpha: 0.12), child: const Icon(Icons.image, color: Colors.grey, size: 45)),
              ),
            ),
            
            // Slate Premium Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Text Content
            Positioned(
              top: 22,
              right: 22,
              left: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Product Name with Label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'اسم المنتج',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24, // تكبير الخط بناءً على الطلب
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 18),

                  // Price Tag with Label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'سعر المنتج',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
                        ),
                        child: Text(
                          price, // رقم فقط بدون ج.م
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Decorative Corner Icon
            Positioned(
              bottom: 18,
              left: 18,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

