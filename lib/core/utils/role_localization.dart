/// يترجم رتبة المستخدم (بالإنجليزية من قاعدة البيانات) إلى العربية للعرض
String roleToArabic(String? role) {
  switch (role?.toString().toLowerCase()) {
    case 'owner':
      return 'مالك';
    case 'user':
      return 'مستخدم';
    case 'customer':
    default:
      return 'عميل';
  }
}
