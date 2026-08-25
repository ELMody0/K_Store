import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import '../../../profile/presentation/pages/user_profile_page.dart';
import '../../../../core/utils/role_localization.dart';
import 'package:k_store/core/widgets/app_image.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _searchQuery = '';

  final Map<String, String> _pendingRoleUpdates = {};
  final Map<String, bool> _pendingVerificationUpdates = {};

  Future<void> _updateUserRole(String userId, String newRole) async {
    setState(() => _pendingRoleUpdates[userId] = newRole);
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
      debugPrint('✅ Role updated successfully for $userId to $newRole');
    } catch (e) {
      debugPrint('❌ Role update failed: $e');
      if (mounted) setState(() => _pendingRoleUpdates.remove(userId));
    }
  }

  Future<void> _toggleVerification(String userId, bool currentStatus) async {
    setState(() => _pendingVerificationUpdates[userId] = !currentStatus);
    try {
      await _supabase.from('profiles').update({'is_verified': !currentStatus}).eq('id', userId);
      debugPrint('✅ Verification updated successfully for $userId');
    } catch (e) {
      debugPrint('❌ Verification update failed: $e');
      if (mounted) setState(() => _pendingVerificationUpdates.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إدارة المستخدمين', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, foregroundColor: textColor, elevation: 0,
      ),
      body: WavyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(hintText: 'البحث عن مستخدم...', prefixIcon: Icon(Icons.search)),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase.from('profiles').stream(primaryKey: ['id']).order('full_name'),
                  builder: (context, snapshot) {
                    final users = snapshot.data?.where((u) => (u['full_name']?.toString().toLowerCase() ?? '').contains(_searchQuery)).toList() ?? [];
                    // Clean up pending updates when stream confirms the change
                    for (final user in users) {
                      final id = user['id']?.toString();
                      final pendingRole = _pendingRoleUpdates[id];
                      if (pendingRole != null && user['role'] == pendingRole) {
                        _pendingRoleUpdates.remove(id);
                      }
                      final pendingVerification = _pendingVerificationUpdates[id];
                      if (pendingVerification != null && user['is_verified'] == pendingVerification) {
                        _pendingVerificationUpdates.remove(id);
                      }
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final bool isVerified = _pendingVerificationUpdates[user['id']] ?? (user['is_verified'] ?? false);
                        return FadeInUp(
                          delay: Duration(milliseconds: index * 50),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(color: isDark ? AppColors.darkGrey : Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: ExpansionTile(
                              leading: AppCircleAvatar(imageUrl: user['avatar_url'], radius: 20),
                              title: Row(
                                children: [
                                  Text(user['full_name'] ?? 'مستخدم', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                  if (isVerified) const SizedBox(width: 5),
                                  if (isVerified) const Icon(Icons.verified_rounded, color: Colors.grey, size: 16),
                                ],
                              ),
                              subtitle: Text(roleToArabic(user['role'])),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      // تغيير الرتبة
                                      DropdownButton<String>(
                                        value: _pendingRoleUpdates[user['id']] ?? (['customer', 'user', 'owner'].contains(user['role']) ? user['role'] : 'customer'),
                                        dropdownColor: isDark ? AppColors.darkGrey : Colors.white,
                                        underline: const SizedBox(),
                                        items: ['customer', 'user', 'owner'].map((r) => DropdownMenuItem(value: r, child: Text(roleToArabic(r), style: TextStyle(color: textColor, fontSize: 12)))).toList(),
                                        onChanged: (val) => _updateUserRole(user['id'], val!),
                                      ),
                                      // زر التوثيق
                                      TextButton.icon(
                                        onPressed: () => _toggleVerification(user['id'], isVerified),
                                        icon: Icon(isVerified ? Icons.verified_user : Icons.verified_user_outlined, color: Colors.grey),
                                        label: Text(isVerified ? 'إلغاء التوثيق' : 'توثيق الحساب', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ),
                                      // فتح البروفايل
                                      IconButton(icon: const Icon(Icons.open_in_new_rounded, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userId: user['id'])))),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
