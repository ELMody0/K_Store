import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import '../../../profile/presentation/pages/chat_room_page.dart';
import '../../../profile/presentation/pages/user_profile_page.dart';
import 'package:k_store/core/widgets/app_image.dart';
import 'package:k_store/core/widgets/empty_state.dart';
import 'package:k_store/core/widgets/app_snackbar.dart';

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _reportController = TextEditingController();
  late PageController _pageController;
  int _currentPage = 0;
  late List<String> _allImages;
  bool _isOwner = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkOwnership();
    _loadUserRole();
    final List gallery = widget.product['images_urls'] ?? [];
    final String? thumb = widget.product['thumbnail_url'];
    _allImages = thumb != null ? [thumb, ...gallery.cast<String>()] : gallery.cast<String>();
  }

  void _checkOwnership() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == widget.product['user_id']) {
      setState(() => _isOwner = true);
    }
  }

  Future<void> _loadUserRole() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      final data = await _supabase.from('profiles').select('role').eq('id', userId).maybeSingle();
      if (mounted) setState(() => _userRole = data?['role']?.toString().toLowerCase());
    }
  }

  Future<void> _reportProduct() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
      return;
    }
    if (myId == widget.product['user_id']) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكنك الإبلاغ عن منتجك')));
      return;
    }
    _reportController.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: const Text('أبلغ عن المنتج', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _reportController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'اكتب سبب البلاغ...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _reportController.text),
            child: const Text('إرسال', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await _supabase.from('reports').insert({
        'reporter_id': myId,
        'reported_user_id': widget.product['user_id'],
        'reported_product_id': widget.product['id'],
        'report_type': 'product',
        'content': reason.trim(),
        'status': 'pending',
      });
      if (mounted) AppSnackBar.show(context, 'تم إرسال البلاغ', success: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'تعذّر الإبلاغ: $e', error: true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: const Text('حذف المنشور؟', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا المنتج نهائياً؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('products').delete().eq('id', widget.product['id']);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المنشور')));
      }
    }
  }

  /// يفتح الشات مباشرة والمنتج مرفق فوق حقل الكتابة — المستخدم يكتب
  /// استفساره من داخل الشات براحته، واسم البائع الحقيقي يظهر في الأعلى.
  Future<void> _contactSeller() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
      return;
    }
    final myId = currentUser.id;
    final sellerId = widget.product['user_id'];
    if (myId == sellerId) return;

    try {
      // جلب اسم البائع الحقيقي بدلاً من كلمة "البائع"
      String sellerName = 'البائع';
      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', sellerId)
            .single();
        final fetchedName = profile['full_name']?.toString().trim() ?? '';
        if (fetchedName.isNotEmpty) sellerName = fetchedName;
      } catch (_) {}

      final ids = [myId, sellerId]..sort();
      // ندوّر على محادثة عادية موجودة بين الزوجين (في Dart لتفادي غموض .or/.and)
      final myChats = await _supabase
          .from('chats')
          .select('id, user1_id, user2_id, user1_hidden, user2_hidden')
          .eq('is_support', false)
          .or('user1_id.eq.$myId,user2_id.eq.$myId');
      final pairChats = myChats.where((c) =>
          (c['user1_id'] == ids[0] && c['user2_id'] == ids[1]) ||
          (c['user1_id'] == ids[1] && c['user2_id'] == ids[0])).toList();
      final existing = pairChats.isNotEmpty ? pairChats.first : null;

      String chatId;
      if (existing != null) {
        // نفتح نفس المحادثة ونفك إخفاءها عنده (الرسايل القديمة متخفية عنه من قبل)
        chatId = existing['id'];
        final hiddenCol = ids[0] == myId ? 'user1_hidden' : 'user2_hidden';
        await _supabase.from('chats').update({hiddenCol: false}).eq('id', chatId);
      } else {
        final created = await _supabase
            .from('chats')
            .insert({
              'user1_id': ids[0],
              'user2_id': ids[1],
              'is_support': false,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        chatId = created['id'];
      }

      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatRoomPage(
                      chatId: chatId,
                      otherUserName: sellerName,
                      attachedProduct: widget.product,
                    )));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_rounded, color: Colors.amberAccent, size: 28), // تغيير للأصفر وشكل دائري أكثر
            onPressed: _reportProduct,
            tooltip: 'أبلغ عن المنتج',
          ),
          if (_isOwner || _userRole == 'owner')
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: CircleAvatar(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                child: IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                  onPressed: _deleteProduct,
                ),
              ),
            ),
        ],
      ),
      body: WavyBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildImageSlider(),
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainInfo(textColor),
                    const SizedBox(height: 40),
                    _buildDescription(textColor),
                    const SizedBox(height: 50),
                    _buildCommentsHeader(textColor),
                    const SizedBox(height: 20),
                    _buildCommentsList(textColor, isDark),
                    const SizedBox(height: 25),
                    _buildCommentInput(textColor, isDark),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isOwner ? null : _buildContactButton(textColor, isDark),
    );
  }

  Widget _buildImageSlider() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Hero(
          tag: 'prod_${widget.product['id']}',
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(bottom: Radius.circular(40))),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _allImages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => AppNetworkImage(url: _allImages[i]),
              ),
            ),
          ),
        ),
        if (_allImages.length > 1)
          Positioned(
            bottom: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_allImages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6, width: _currentPage == i ? 20 : 6,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: _currentPage == i ? 1 : 0.4), borderRadius: BorderRadius.circular(10)),
              )),
            ),
          ),
      ],
    );
  }

  Widget _buildMainInfo(Color textColor) {
    final String price = (widget.product['price']?.toString() ?? '').replaceAll(RegExp(r'\.0$'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInDown(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('عنوان المنتج', style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Text(
                      widget.product['name_ar'], 
                      style: TextStyle(color: textColor, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1)
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: textColor.withValues(alpha: 0.1), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Text('السعر', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Color textColor) {
    final String desc = (widget.product['description_ar'] ?? '').toString().trim();
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5, height: 20, 
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.8), 
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: textColor.withValues(alpha: 0.2), blurRadius: 10)]
                )
              ),
              const SizedBox(width: 12),
              Text('المواصفات والتفاصيل', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: textColor.withValues(alpha: 0.06)),
            ),
            child: Text(
              desc.isEmpty ? 'لا يوجد وصف متاح لهذا المنتج حالياً.' : desc,
              style: TextStyle(color: textColor.withValues(alpha: 0.75), fontSize: 16, height: 1.8, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsHeader(Color textColor) {
    return Row(
      children: [
        Container(
          width: 5, height: 20, 
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.8), 
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: textColor.withValues(alpha: 0.2), blurRadius: 10)]
          )
        ),
        const SizedBox(width: 12),
        Text('آراء المجتمع', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildCommentInput(Color textColor, bool isDark) {
    return FadeInUp(
      child: Container(
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: textColor.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'اكتب رأيك هنا...',
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                final user = _supabase.auth.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول للتعليق')));
                  return;
                }
                if (_commentController.text.trim().isNotEmpty) {
                  _supabase.from('comments').insert({
                    'product_id': widget.product['id'],
                    'user_id': user.id,
                    'content': _commentController.text.trim(),
                  }).then((_) { if (mounted) _commentController.clear(); });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
                child: Icon(Icons.send_rounded, color: isDark ? Colors.black : Colors.white, size: 20),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList(Color textColor, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('comments')
          .stream(primaryKey: ['id'])
          .eq('product_id', widget.product['id'])
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final comments = snapshot.data ?? [];
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: EmptyState(icon: Icons.comment_outlined, message: 'لا توجد تعليقات بعد'),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) => _buildCommentItem(comments[index], textColor, isDark),
        );
      },
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, Color textColor, bool isDark) {
    return FutureBuilder(
      future: _supabase.from('profiles').select().eq('id', comment['user_id']).single(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox();
        final user = userSnap.data!;
        final currentUserId = _supabase.auth.currentUser?.id;
        // المالك يحذف أي كومنت، وصاحب البوست (customer) يحذف أي كومنت على بوسته، وكل مستخدم يحذف كومنته بس
        final bool canDelete = _isOwner || comment['user_id'] == currentUserId || _userRole == 'owner';

        return FadeInLeft(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: textColor.withValues(alpha: 0.05)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الضغط على الصورة فقط
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userId: user['id']))),
                    child: AppCircleAvatar(
                      imageUrl: user['avatar_url'],
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الضغط على الاسم فقط
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userId: user['id']))),
                          child: Text(
                            user['full_name'] ?? 'مستخدم', 
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14)
                          ),
                        ),
                        const SizedBox(height: 4),
                        // النص غير قابل للضغط لفتح البروفايل
                        Text(
                          comment['content'], 
                          style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14)
                        ),
                      ],
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                      onPressed: () async {
                        final ctx = context;
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: AppColors.darkGrey,
                            title: const Text('حذف التعليق؟', style: TextStyle(color: Colors.white)),
                            content: const Text('هل أنت متأكد من حذف هذا التعليق؟', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && ctx.mounted) {
                          await _supabase.from('comments').delete().eq('id', comment['id']);
                          if (ctx.mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('تم حذف التعليق')),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactButton(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 35),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -10))],
      ),
      child: ElevatedButton.icon(
        onPressed: _contactSeller,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('تواصل مع البائع الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: textColor, foregroundColor: isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          minimumSize: const Size(double.infinity, 70),
        ),
      ),
    );
  }
}
