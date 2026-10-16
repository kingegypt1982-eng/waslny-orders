import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';

const _pBg = Color(0xFF03151D);
const _pCard = Color(0xFF092630);
const _pGreen = Color(0xFF00D875);
const _pMuted = Color(0xFF9FB5BD);
const _pBorder = Color(0xFF24515B);

/// Customer/captain account screen: dark Arabic RTL.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _pCard,
        title: const Text(
          'تسجيل الخروج؟',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'هل تريد تسجيل الخروج من حسابك؟',
          style: TextStyle(color: _pMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع', style: TextStyle(color: _pMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _pGreen),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(apiClientProvider).clearSession();
    ref.read(sessionProvider.notifier).state = null;
    if (context.mounted) context.go('/');
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _pCard,
        title: const Text(
          'المساعدة والدعم',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'للاستفسارات والدعم الفني تواصل معنا على support@waslny.com وسنرد عليك في أقرب وقت.',
          style: TextStyle(color: _pMuted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'حسنًا',
              style: TextStyle(color: _pGreen, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _pCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PolicySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider) ?? {};
    final name = user['name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final role = switch (user['role']?.toString()) {
      'CAPTAIN' => 'مندوب',
      'ADMIN' => 'مدير',
      _ => 'عميل',
    };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pBg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 34,
                backgroundColor: _pCard,
                child: Text(
                  name.isEmpty ? '؟' : name.characters.first,
                  style: const TextStyle(
                    color: _pGreen,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _pMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _pGreen.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _pGreen),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: _pGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _PTile(
                icon: Icons.person_outline_rounded,
                title: 'بيانات الحساب',
                subtitle: email.isEmpty ? '—' : email,
                onTap: null,
              ),
              const SizedBox(height: 10),
              _PTile(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                subtitle: 'عرض تحديثات طلباتك',
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 10),
              _PTile(
                icon: Icons.description_outlined,
                title: 'السياسات والشروط',
                subtitle: 'اطلع على الشروط والأحكام',
                onTap: () => _showPolicy(context),
              ),
              const SizedBox(height: 10),
              _PTile(
                icon: Icons.help_outline_rounded,
                title: 'المساعدة والدعم',
                subtitle: 'تواصل معنا',
                onTap: () => _showHelp(context),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _pBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(fontWeight: FontWeight.w700),
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

class _PTile extends StatelessWidget {
  const _PTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: _pCard,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _pBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _pGreen.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: _pGreen, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _pMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _pMuted,
                size: 16,
              ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet showing GET /policies/TERMS_CLIENT with loading/error states.
class _PolicySheet extends ConsumerStatefulWidget {
  const _PolicySheet();
  @override
  ConsumerState<_PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends ConsumerState<_PolicySheet> {
  Map<String, dynamic>? _policy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final policy = await ref
          .read(apiClientProvider)
          .getMap('/policies/TERMS_CLIENT');
      if (mounted) {
        setState(() {
          _policy = policy;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = ApiClient.errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _pBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (policy == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: _pGreen),
                ),
              )
            else if (policy == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعذر تحميل السياسة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_error',
                    style: const TextStyle(color: _pMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pGreen,
                      foregroundColor: _pBg,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              )
            else ...[
              Text(
                '${policy['title'] ?? 'شروط الاستخدام'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${policy['text'] ?? ''}',
                style: const TextStyle(
                  color: _pMuted,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
