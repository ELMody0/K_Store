// ignore_for_file: spell_check_messenger, depend_on_referenced_packages
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/theme/theme_manager.dart';
import 'package:k_store/core/services/notification_service.dart';
import 'package:k_store/core/services/fcm_service.dart';
import 'package:k_store/features/home/presentation/pages/splash_page.dart';

void main() async {
  // تشغيل التطبيق بالكامل داخل Zone آمن لمعالجة أي أخطاء غير متزامنة (Async Errors) لمنع الانهيار فجأة
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();

      // تهيئة Firebase لخدمة الإشعارات (FCM)
      await Firebase.initializeApp();
      // استعادة ثيم المستخدم المحفوظ (فاتح/داكن) قبل تشغيل الواجهة
      await ThemeManager.init();
      

    // معالجة وحجز أخطاء إطار العمل فلاتر لمنع خروج التطبيق المفاجئ عند حدوث أي خطأ بالواجهات
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('⚠️ Flutter Core Error Intercepted: ${details.exception}');
      debugPrint('StackTrace: ${details.stack}');
    };

    // معالجة وحجز كافة الأخطاء غير المتوقعة بشكل عام على مستوى المنصة لمنع انهيار أو خروج التطبيق
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('⚠️ Unhandled Application Exception Intercepted:');
      debugPrint('Error Details: $error');
      debugPrint('Stacktrace:\n$stack');
      return true; // يبلغ النظام بأن الخطأ تم التعامل معه ولن يتم إغلاق التطبيق فجأة
    };

    const String supabaseUrl = 'https://mcygszronpkcxnhfbuyc.supabase.co';
    
    // تم استبدال المفتاح بمفتاح الـ anon السحابي الصحيح الخاص بك لحل مشكلة التعليق والانهيار
    const String publishableKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jeWdzenJvbnBrY3huaGZidXljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMzIzNDEsImV4cCI6MjEwMjgwODM0MX0.P1iJFvCR9DW92P59F6zhAWpgzST1Tt1XvpSk3xd5sCk'; 

    // فحص ذكي لتنبيه المطور بالخطأ الفادح في نوع المفتاح المستخدم
    if (supabaseUrl.contains('sup abase.co') && !publishableKey.startsWith('eyJ')) {
      debugPrint('=========================================');
      debugPrint('⚠️ خطأ فادح يمنع عمل التطبيق ويسبب الانهيار:');
      debugPrint('أنت تستخدم رابط مستضاف سحابياً (.sup-abase.co) ولكنك تضع مفتاح محلي (sb_publishable_...).');
      debugPrint('هذا يتسبب في توقف تحميل الرسائل وانهيار التطبيق عند تسجيل الحساب!');
      debugPrint('الرجاء استبداله بمفتاح الـ "anon" السحابي من لوحة تحكم Sup abase (والذي يبدأ دائماً بـ eyJ).');
      debugPrint('=========================================');
    }

    debugPrint('🚀 K-Shop: بدء Sup abase.initialize...');
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: publishableKey,
        realtimeClientOptions: const RealtimeClientOptions(
          timeout: Duration(seconds: 30),
        ),
        debug: true, // تم تفعيل الـ debug لمراقبة أخطاء الاتصال وقراءة السجلات بوضوح
      ).timeout(const Duration(seconds: 25));
      debugPrint('✅ K-Shop: Sup abase.initialize اكتمل بنجاح');

    // ته/init خدمة الإشعارات الداخلي (Realtime) بعد ته Supabase
    try {
      await NotificationService().init();
      debugPrint('✅ K-Shop: NotificationService تم تهيارها');
    } catch (e) {
      debugPrint('⚠️ K-Shop: فشل تهيار NotificationService: $e');
    }

    // تهيئة خدمة FCM وتسجيل التوكن + طلب إذن الإشعارات
    try {
      await FcmService().init();
      debugPrint('✅ K-Shop: FCM تم تهيئته');
    } catch (e) {
      debugPrint('⚠️ K-Shop: فشل تهيئة FCM: $e');
    }
    } catch (e, st) {
      // لو الشبكة بطيئة/مقطوعة نكمل تشغيل الواجهة على أي حال بدل الشاشة البيضاء
      debugPrint('🚨 K-Shop: Sup abase.initialize فشل أو تجاوز المهلة: $e');
      debugPrint('$st');
    }

    debugPrint('🚀 K-Shop: runApp...');
    runApp(const MyApp());
  }, (error, stackTrace) {
    // التقاط وحظر الأخطاء الحرجة غير المتزامنة (مثل أخطاء التسجيل والاتصال بالخادم) ومنع الخروج من التطبيق
    debugPrint('⚠️ Critical Async Error Caught by zonedGuarded: $error');
    debugPrint('StackTrace:\n$stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'K Shop',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          locale: const Locale('en'),
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const SplashPage(),
        );
      },
    );
  }
}