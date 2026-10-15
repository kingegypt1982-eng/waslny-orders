import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'core/api_client.dart';
import 'screens/home_screen.dart';

const _green = Color(0xFF19785F);
const _ink = Color(0xFF23362C);
const _muted = Color(0xFF829087);
const _cairo = LatLng(30.0444, 31.2357);

class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    return user == null ? const WelcomeScreen() : HomeShell(user: user);
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _selectRole(
    BuildContext context,
    WidgetRef ref,
    String role,
  ) async {
    await ref.read(preferencesProvider).setString('selected_role', role);
    if (context.mounted) context.push('/register?role=$role');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        // الخلفية
        Image.asset('assets/images/waslny_hero.png', fit: BoxFit.cover),

        // طبقة تعتيم لعناصر الواجهة
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                const Color(0xFF03131E).withOpacity(0.85),
              ],
            ),
          ),
        ),

        // عناصر Flutter فوق الخلفية
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 45),
              const Icon(Icons.location_on, color: Color(0xFF00C96B), size: 58),
              const Text(
                'Waslny',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Orders',
                style: TextStyle(color: Color(0xFFB8D982), fontSize: 21),
              ),
              const Spacer(),
              const Text(
                'اختر نوع الحساب',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 18),

              // زرا المندوب والعميل
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: const Color(0xFF00C96B),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => _selectRole(context, ref, 'CAPTAIN'),
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            height: 56,
                            child: Center(
                              child: Text(
                                'مندوب',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: Color(0xFF00C96B),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _selectRole(context, ref, 'CLIENT'),
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            height: 56,
                            child: Center(
                              child: Text(
                                'عميل',
                                style: TextStyle(
                                  color: Color(0xFF00C96B),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    ),
  );
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.register, required this.role});
  final bool register;
  final String role;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _vehicleType = TextEditingController(text: 'Motorcycle');
  final _plate = TextEditingController();
  late bool _register = widget.register;
  late String _role = widget.role;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _phone,
      _vehicleType,
      _plate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final payload = _register
          ? await api.post(
              '/auth/register',
              data: {
                'name': _name.text.trim(),
                'email': _email.text.trim(),
                'password': _password.text,
                'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                'role': _role,
                if (_role == 'CAPTAIN') 'vehicleType': _vehicleType.text.trim(),
                if (_role == 'CAPTAIN') 'vehiclePlate': _plate.text.trim(),
              },
            )
          : await api.post(
              '/auth/login',
              data: {'email': _email.text.trim(), 'password': _password.text},
            );
      await api.saveSession(payload);
      ref.read(sessionProvider.notifier).state = Map<String, dynamic>.from(
        payload['user'] as Map,
      );
      if (mounted) {
        context.go(
          _register && _role == 'CAPTAIN' ? '/captain-documents' : '/',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(context, ApiClient.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Wasalny Orders'),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _register ? 'Join Wasalny' : 'Welcome back',
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _register
                        ? 'Create your account to get started.'
                        : 'Sign in to continue to your deliveries.',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 24),
                  if (_register) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'CLIENT', label: Text('Client')),
                        ButtonSegment(value: 'CAPTAIN', label: Text('Captain')),
                      ],
                      selected: {_role},
                      onSelectionChanged: (value) =>
                          setState(() => _role = value.first),
                    ),
                    const SizedBox(height: 17),
                    _field(
                      _name,
                      'Full name',
                      icon: Icons.person_outline,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _phone,
                      'Phone for delivery contact',
                      icon: Icons.phone_outlined,
                      optional: true,
                    ),
                    if (_role == 'CAPTAIN') ...[
                      const SizedBox(height: 14),
                      const Text(
                        'VEHICLE DETAILS',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 9),
                      _field(
                        _vehicleType,
                        'Vehicle type',
                        icon: Icons.two_wheeler_outlined,
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        _plate,
                        'Vehicle plate',
                        icon: Icons.numbers_outlined,
                        validator: _required,
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'You will add your ID, license, and vehicle documents next.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  _field(
                    _email,
                    'Email address',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter a valid email',
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _password,
                    'Password',
                    icon: Icons.lock_outline,
                    obscure: true,
                    validator: (value) => value != null && value.length >= 8
                        ? null
                        : 'Use at least 8 characters',
                  ),
                  const SizedBox(height: 22),
                  _PrimaryButton(
                    label: _busy
                        ? 'Please wait…'
                        : _register
                        ? 'Create account'
                        : 'Sign in',
                    busy: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? 'Already have an account? Sign in'
                            : 'New to Wasalny? Create an account',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().length < 2 ? 'This field is required' : null;
Widget _field(
  TextEditingController controller,
  String label, {
  IconData? icon,
  bool obscure = false,
  bool optional = false,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) => TextFormField(
  controller: controller,
  obscureText: obscure,
  keyboardType: keyboardType,
  validator: optional ? null : validator,
  decoration: InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, size: 19),
    suffixText: optional ? 'optional' : null,
  ),
);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final captain = widget.user['role'] == 'CAPTAIN';
    final views = captain
        ? [
            CaptainHome(user: widget.user),
            const HistoryScreen(),
            const WalletScreen(),
            const ProfileScreen(),
          ]
        : [
            WaslnyHomeScreen(
              onNavigate: (index) => setState(() => _index = index),
              loadOrders: () => ref.read(apiClientProvider).getList('/orders'),
            ),
            const HistoryScreen(),
            const ProfileScreen(),
          ];
    final labels = captain
        ? const ['Deliver', 'Trips', 'Wallet', 'Profile']
        : const ['الرئيسية', 'طلباتي', 'الملف'];
    final icons = captain
        ? const [
            Icons.route_outlined,
            Icons.receipt_long_outlined,
            Icons.account_balance_wallet_outlined,
            Icons.person_outline,
          ]
        : const [
            Icons.add_box_outlined,
            Icons.receipt_long_outlined,
            Icons.person_outline,
          ];
    return Scaffold(
      body: IndexedStack(index: _index, children: views),
      bottomNavigationBar: Directionality(
        textDirection: captain ? TextDirection.ltr : TextDirection.rtl,
        child: NavigationBar(
          backgroundColor: captain ? null : const Color(0xFF041920),
          indicatorColor: captain ? null : const Color(0xFF103D3B),
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: [
            for (var i = 0; i < labels.length; i++)
              NavigationDestination(
                icon: Icon(
                  icons[i],
                  color: captain ? null : const Color(0xFF9FB5BD),
                ),
                selectedIcon: Icon(
                  icons[i],
                  color: captain ? null : const Color(0xFF00D875),
                ),
                label: labels[i],
              ),
          ],
        ),
      ),
    );
  }
}

class ClientHome extends ConsumerWidget {
  const ClientHome({
    super.key,
    required this.user,
    required this.isArabic,
    required this.onToggleLanguage,
    required this.onViewAll,
  });

  final Map<String, dynamic> user;
  final bool isArabic;
  final VoidCallback onToggleLanguage;
  final VoidCallback onViewAll;

  String _localized(String english, String arabic) =>
      isArabic ? arabic : english;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Directionality(
    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientOrdersProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_localized('Hello', 'صباح الخير')}, ${_firstName(user['name'] as String?)}',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _localized(
                            'Where should we deliver today?',
                            'أين نوصّل اليوم؟',
                          ),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onToggleLanguage,
                    child: Text(isArabic ? 'English' : 'العربية'),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: _localized(
                    'Search for a place or service',
                    'ابحث عن مكان أو خدمة',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6EBE6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE6EBE6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final service in <(IconData, String)>[
                    (
                      Icons.description_outlined,
                      _localized('Documents', 'أوراق'),
                    ),
                    (Icons.article_outlined, _localized('Papers', 'مستندات')),
                    (
                      Icons.inventory_2_outlined,
                      _localized('Packages', 'طرود'),
                    ),
                    (
                      Icons.shopping_bag_outlined,
                      _localized('Shopping', 'مشتريات'),
                    ),
                  ])
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAF4EC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(service.$1, color: _green, size: 21),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            service.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localized(
                        'READY WHEN YOU ARE',
                        'جاهزون عندما تكون مستعدًا',
                      ),
                      style: const TextStyle(
                        color: _green,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localized(
                        'Send a shipment\nacross the city.',
                        'أرسل شحنتك\nإلى أي مكان في المدينة.',
                      ),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PrimaryButton(
                      label: _localized('Create delivery', 'إنشاء طلب توصيل'),
                      icon: Icons.add,
                      onPressed: () => context.push('/new-order'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: _localized('Recent orders', 'الطلبات الأخيرة'),
                action: _localized('View all', 'عرض الكل'),
                onAction: onViewAll,
              ),
              const SizedBox(height: 10),
              _OrderFeed(isArabic: isArabic),
            ],
          ),
        ),
      ),
    ),
  );
}

class CaptainHome extends ConsumerWidget {
  const CaptainHome({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(captainProfileProvider);
            ref.invalidate(availableOrdersProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _TopHeader(
                title: 'Captain ${_firstName(user['name'] as String?)}',
                subtitle: 'Your next delivery starts here.',
                icon: Icons.notifications_none,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final result = await context.push<Map<String, dynamic>>(
                      '/map-picker?title=Set%20delivery%20area',
                    );
                    if (result == null || !context.mounted) return;
                    final point = LatLng(
                      result['lat'] as double,
                      result['lon'] as double,
                    );
                    ref.read(captainLocationProvider.notifier).state = point;
                    try {
                      await api.post(
                        '/captains/location',
                        data: {
                          'latitude': point.latitude,
                          'longitude': point.longitude,
                        },
                      );
                      ref.invalidate(availableOrdersProvider);
                    } catch (error) {
                      if (context.mounted) {
                        _showMessage(context, ApiClient.errorMessage(error));
                      }
                    }
                  },
                  icon: const Icon(Icons.location_searching, size: 16),
                  label: const Text('Set my delivery area'),
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>>(
                future: api.getMap('/captains/me'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const LinearProgressIndicator();
                  if (snapshot.hasError)
                    return _ErrorBox(
                      message: ApiClient.errorMessage(snapshot.error!),
                    );
                  final status =
                      snapshot.data?['status'] as String? ?? 'PENDING';
                  if (status != 'ACTIVE') return _ApprovalPanel(status: status);
                  return const _AvailableOrders();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApprovalPanel extends StatelessWidget {
  const _ApprovalPanel({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFF4E5CA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          status == 'REJECTED'
              ? Icons.info_outline
              : Icons.hourglass_top_rounded,
          color: const Color(0xFFAA7B35),
        ),
        const SizedBox(height: 11),
        Text(
          status == 'REJECTED'
              ? 'Application needs attention'
              : 'Your application is under review',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _ink,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The Wasalny team will review your documents. You can accept deliveries once your captain profile is approved.',
          style: TextStyle(color: _muted, height: 1.45, fontSize: 12),
        ),
        const SizedBox(height: 13),
        OutlinedButton.icon(
          onPressed: () => context.push('/captain-documents'),
          icon: const Icon(Icons.upload_file_outlined, size: 17),
          label: const Text('Upload captain documents'),
        ),
      ],
    ),
  );
}

class CaptainDocumentsScreen extends ConsumerStatefulWidget {
  const CaptainDocumentsScreen({super.key});
  @override
  ConsumerState<CaptainDocumentsScreen> createState() =>
      _CaptainDocumentsScreenState();
}

class _CaptainDocumentsScreenState
    extends ConsumerState<CaptainDocumentsScreen> {
  late Future<Map<String, dynamic>> _profile;
  String? _uploading;

  @override
  void initState() {
    super.initState();
    _profile = ref.read(apiClientProvider).getMap('/captains/me');
  }

  Future<void> _pickAndUpload(String type) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty || !mounted) return;
    final file = selection.files.single;
    if (file.bytes == null) {
      _showMessage(context, 'Could not read the selected document.');
      return;
    }
    setState(() => _uploading = type);
    try {
      await ref
          .read(apiClientProvider)
          .uploadFile('/captains/documents/$type', file.bytes!, file.name);
      setState(() {
        _profile = ref.read(apiClientProvider).getMap('/captains/me');
      });
      if (mounted) _showMessage(context, 'Document uploaded.');
    } catch (error) {
      if (mounted) _showMessage(context, ApiClient.errorMessage(error));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Captain documents'),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _ErrorBox(
                message: ApiClient.errorMessage(snapshot.error!),
              ),
            ),
          );
        }
        final profile = snapshot.data ?? {};
        const documents = {
          'identity': ('National ID', 'nationalIdDocument'),
          'license': ('Driving license', 'licenseDocument'),
          'vehicle': ('Vehicle registration', 'vehicleDocument'),
        };
        final complete = documents.values.every(
          (entry) =>
              profile[entry.$2] is String &&
              profile[entry.$2] != 'PENDING_UPLOAD',
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Verification documents',
              style: TextStyle(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add clear PDF or image files. Each file can be up to 8 MB.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 17),
            for (final entry in documents.entries)
              Builder(
                builder: (context) {
                  final uploaded = profile[entry.value.$2] != 'PENDING_UPLOAD';
                  final busy = _uploading == entry.key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: _cardDecoration,
                    child: ListTile(
                      leading: Icon(
                        uploaded ? Icons.check_circle : Icons.upload_file,
                        color: uploaded ? _green : _muted,
                      ),
                      title: Text(entry.value.$1),
                      subtitle: Text(uploaded ? 'Uploaded' : 'Required'),
                      trailing: TextButton(
                        onPressed: _uploading == null
                            ? () => _pickAndUpload(entry.key)
                            : null,
                        child: Text(
                          busy
                              ? 'Uploading…'
                              : uploaded
                              ? 'Replace'
                              : 'Add',
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 13),
            _PrimaryButton(
              label: complete
                  ? 'Return to captain home'
                  : 'Upload all documents to continue',
              icon: Icons.check,
              onPressed: complete ? () => context.go('/') : null,
            ),
          ],
        );
      },
    ),
  );
}

class _AvailableOrders extends ConsumerWidget {
  const _AvailableOrders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(availableOrdersProvider);
    return ordersState.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => _ErrorBox(message: ApiClient.errorMessage(error)),
      data: (orders) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Nearby deliveries'),
            const SizedBox(height: 10),
            if (orders.isEmpty)
              const _EmptyState(
                icon: Icons.near_me_outlined,
                title: 'No orders nearby',
                subtitle:
                    'New requests will appear here when they match your area.',
              ),
            for (final item in orders)
              _AvailableOrderCard(
                order: Map<String, dynamic>.from(item as Map),
              ),
          ],
        );
      },
    );
  }
}

class _AvailableOrderCard extends ConsumerWidget {
  const _AvailableOrderCard({required this.order});
  final Map<String, dynamic> order;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final busy = ref.watch(orderActionProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${order['category'] ?? 'SHIPMENT'} · ${order['reference'] ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                'EGP ${order['price']}',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteLine(
            pickup: order['pickupLabel'] as String? ?? '',
            delivery: order['deliveryLabel'] as String? ?? '',
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                _MoneyRow(label: 'رسوم التوصيل', value: _egp(order['price'])),
                const SizedBox(height: 6),
                _MoneyRow(
                  label: 'عمولة الشركة (10%) تُخصم من محفظتك',
                  value: _egp(order['commission']),
                ),
                const Divider(height: 20),
                _MoneyRow(
                  label: 'صافي ربحك',
                  value: _egp(
                    _toDouble(order['price']) - _toDouble(order['commission']),
                  ),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      ref.read(orderActionProvider.notifier).state = true;
                      try {
                        await api.post('/orders/${order['id']}/accept');
                        if (context.mounted) {
                          _showMessage(context, 'Delivery accepted');
                          ref.invalidate(availableOrdersProvider);
                        }
                      } catch (error) {
                        if (context.mounted)
                          _showMessage(context, ApiClient.errorMessage(error));
                      } finally {
                        ref.read(orderActionProvider.notifier).state = false;
                      }
                    },
              icon: const Icon(Icons.check, size: 17),
              label: Text(busy ? 'Accepting…' : 'Accept delivery'),
            ),
          ),
        ],
      ),
    );
  }
}

final orderActionProvider = StateProvider<bool>((ref) => false);
final clientOrdersProvider = FutureProvider<List<dynamic>>(
  (ref) => ref.watch(apiClientProvider).getList('/orders'),
);
final availableOrdersProvider = FutureProvider<List<dynamic>>((ref) {
  final point = ref.watch(captainLocationProvider);
  return ref
      .watch(apiClientProvider)
      .getList(
        '/orders/available',
        query: {'latitude': point.latitude, 'longitude': point.longitude},
      );
});
final captainLocationProvider = StateProvider<LatLng>((ref) => _cairo);
final captainProfileProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(apiClientProvider).getMap('/captains/me'),
);

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key, this.initialCategory});
  final String? initialCategory;
  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupLabel = TextEditingController(text: 'Cairo, Egypt');
  final _deliveryLabel = TextEditingController();
  final _description = TextEditingController();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  LatLng _pickup = _cairo;
  LatLng _delivery = const LatLng(30.0131, 31.2089);
  String _category = 'PACKAGE';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    const supportedCategories = {
      'PAPERS',
      'MATERIALS',
      'GOODS',
      'SPARE_PARTS',
      'PACKAGE',
      'OTHER',
      'MEDICINES',
      'PURCHASES',
      'FOOD',
      'ELECTRONICS',
    };
    if (supportedCategories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _pickupLabel.dispose();
    _deliveryLabel.dispose();
    _description.dispose();
    _recipient.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick(bool pickup) async {
    final result = await context.push<Map<String, dynamic>>(
      '/map-picker?title=${pickup ? 'Choose pickup' : 'Choose delivery'}',
    );
    if (result == null || !mounted) return;
    final point = LatLng(result['lat'] as double, result['lon'] as double);
    setState(() {
      if (pickup) {
        _pickup = point;
        _pickupLabel.text = 'Selected pickup location';
      } else {
        _delivery = point;
        _deliveryLabel.text = 'Selected delivery location';
      }
    });
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final orderData = {
        'pickupLabel': _pickupLabel.text.trim(),
        'pickupLatitude': _pickup.latitude,
        'pickupLongitude': _pickup.longitude,
        'deliveryLabel': _deliveryLabel.text.trim(),
        'deliveryLatitude': _delivery.latitude,
        'deliveryLongitude': _delivery.longitude,
        'category': _category,
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'recipientName': _recipient.text.trim(),
        'recipientPhone': _phone.text.trim(),
      };
      final quote = await ref
          .read(apiClientProvider)
          .post(
            '/orders/quote',
            data: {
              'pickupLatitude': _pickup.latitude,
              'pickupLongitude': _pickup.longitude,
              'deliveryLatitude': _delivery.latitude,
              'deliveryLongitude': _delivery.longitude,
            },
          );
      if (mounted) {
        await context.push(
          '/order-review',
          extra: {'orderData': orderData, 'quote': quote},
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context, 'تعذر احتساب السعر الآن. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('New delivery'),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 24),
          children: [
            const Text(
              'Shipment route',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            _LocationField(
              label: 'Pickup',
              controller: _pickupLabel,
              icon: Icons.trip_origin,
              onMap: () => _pick(true),
            ),
            const SizedBox(height: 10),
            _LocationField(
              label: 'Deliver to',
              controller: _deliveryLabel,
              icon: Icons.location_on_outlined,
              onMap: () => _pick(false),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Shipment type',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PAPERS',
                  child: Text('Papers & documents'),
                ),
                DropdownMenuItem(value: 'MATERIALS', child: Text('Materials')),
                DropdownMenuItem(value: 'GOODS', child: Text('Goods')),
                DropdownMenuItem(value: 'PURCHASES', child: Text('Purchases')),
                DropdownMenuItem(value: 'FOOD', child: Text('Food and drinks')),
                DropdownMenuItem(value: 'MEDICINES', child: Text('Medicines')),
                DropdownMenuItem(
                  value: 'ELECTRONICS',
                  child: Text('Electronics'),
                ),
                DropdownMenuItem(
                  value: 'SPARE_PARTS',
                  child: Text('Spare parts'),
                ),
                DropdownMenuItem(value: 'PACKAGE', child: Text('Package')),
                DropdownMenuItem(
                  value: 'OTHER',
                  child: Text('Other ready shipment'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? 'PACKAGE'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Shipment details',
                hintText: 'What is the captain picking up? (optional)',
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Recipient details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _recipient,
              decoration: const InputDecoration(
                labelText: 'Recipient name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _required,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Recipient phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => value != null && value.length >= 8
                  ? null
                  : 'Enter a contact number',
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 8),
            _PrimaryButton(
              label: _busy ? 'جارٍ احتساب السعر…' : 'متابعة لمراجعة السعر',
              busy: _busy,
              onPressed: _busy ? null : _calculate,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.onMap,
  });
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final VoidCallback onMap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 19),
          ),
          validator: _required,
        ),
      ),
      const SizedBox(width: 7),
      IconButton.filledTonal(
        tooltip: 'Choose on map',
        onPressed: onMap,
        icon: const Icon(Icons.map_outlined),
      ),
    ],
  );
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, required this.title});
  final String title;
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _selected = _cairo;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _cairo,
            initialZoom: 12,
            onTap: (tap, point) => setState(() => _selected = point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.waslny.orders',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selected,
                  width: 45,
                  height: 45,
                  child: const Icon(
                    Icons.location_pin,
                    size: 42,
                    color: _green,
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: _PrimaryButton(
            label: 'Use this location',
            icon: Icons.check,
            onPressed: () => context.pop({
              'lat': _selected.latitude,
              'lon': _selected.longitude,
            }),
          ),
        ),
      ],
    ),
  );
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Your orders')),
    body: FutureBuilder<List<dynamic>>(
      future: ref.watch(apiClientProvider).getList('/orders'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _ErrorBox(
                message: ApiClient.errorMessage(snapshot.error!),
              ),
            ),
          );
        final orders = snapshot.data ?? [];
        if (orders.isEmpty)
          return const _EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No deliveries yet',
            subtitle: 'Your shipment history will appear here.',
          );
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientOrdersProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in orders)
                _OrderCard(order: Map<String, dynamic>.from(item as Map)),
            ],
          ),
        );
      },
    ),
  );
}

class _OrderFeed extends ConsumerWidget {
  const _OrderFeed({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<List<dynamic>>(
        future: ref.watch(apiClientProvider).getList('/orders'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            );
          if (snapshot.hasError)
            return _ErrorBox(message: ApiClient.errorMessage(snapshot.error!));
          final orders = (snapshot.data ?? []).take(3).toList();
          if (orders.isEmpty)
            return _EmptyState(
              icon: Icons.inventory_2_outlined,
              title: isArabic ? 'لا توجد شحنات نشطة' : 'No active shipments',
              subtitle: isArabic
                  ? 'أنشئ طلب توصيل للبدء.'
                  : 'Create a delivery request to get started.',
            );
          return Column(
            children: [
              for (final item in orders)
                _OrderCard(order: Map<String, dynamic>.from(item as Map)),
            ],
          );
        },
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Map<String, dynamic> order;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/track/${order['id']}'),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order['reference'] ?? 'Shipment'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '${order['status'] ?? ''}'.replaceAll('_', ' '),
                style: const TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _RouteLine(
            pickup: order['pickupLabel'] as String? ?? '',
            delivery: order['deliveryLabel'] as String? ?? '',
          ),
          const SizedBox(height: 9),
          Text(
            'EGP ${order['price'] ?? '—'}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  Future<void> _topUp(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add wallet funds'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount in EGP'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(amount.text)),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (value == null) return;
    try {
      final result = await ref
          .read(apiClientProvider)
          .post('/captains/wallet/top-up', data: {'amount': value});
      if (context.mounted)
        _showMessage(
          context,
          result['message'] as String? ?? 'Payment intent created',
        );
    } catch (error) {
      if (context.mounted) _showMessage(context, ApiClient.errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Captain wallet')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(apiClientProvider).getMap('/captains/wallet'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: _ErrorBox(message: ApiClient.errorMessage(snapshot.error!)),
          );
        final wallet = snapshot.data ?? {};
        final user = wallet['user'] as Map?;
        final transactions = (user?['walletTransactions'] as List?) ?? [];
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'EGP ${wallet['balance'] ?? '0.00'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 13),
                  OutlinedButton.icon(
                    onPressed: () => _topUp(context, ref),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add funds'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Transactions'),
            const SizedBox(height: 9),
            if (transactions.isEmpty)
              const _EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                subtitle: 'Wallet activity will appear here.',
              ),
            for (final item in transactions)
              _TransactionRow(data: Map<String, dynamic>.from(item as Map)),
          ],
        );
      },
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse('${data['amount']}') ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: amount < 0
            ? const Color(0xFFFAEFEC)
            : const Color(0xFFEAF4EC),
        child: Icon(
          amount < 0 ? Icons.arrow_upward : Icons.arrow_downward,
          size: 17,
          color: amount < 0 ? const Color(0xFFB36B58) : _green,
        ),
      ),
      title: Text(
        '${data['type'] ?? 'Transaction'}'.replaceAll('_', ' '),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${data['createdAt'] ?? ''}'.split('T').first,
        style: const TextStyle(fontSize: 10, color: _muted),
      ),
      trailing: Text(
        'EGP ${amount.abs().toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider) ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFE4F1E9),
            child: Text(
              _firstName(user['name'] as String?).substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: _green,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              user['name'] as String? ?? '',
              style: const TextStyle(
                fontSize: 18,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Text(
              user['email'] as String? ?? '',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Account details'),
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & support'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(apiClientProvider).clearSession();
              ref.read(sessionProvider.notifier).state = null;
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
      IconButton(
        onPressed: () {},
        icon: Icon(icon, color: _ink),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _ink,
            fontSize: 16,
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action!,
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.pickup, required this.delivery});
  final String pickup, delivery;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          const Icon(Icons.circle, size: 9, color: _green),
          Container(height: 17, width: 1, color: const Color(0xFFBCCBC0)),
          const Icon(Icons.location_on, size: 13, color: Color(0xFFD18154)),
        ],
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pickup,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              delivery,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final bool emphasize;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: emphasize ? _green : _ink,
          fontSize: emphasize ? 15 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _egp(Object? value) => 'EGP ${_toDouble(value).toStringAsFixed(2)}';

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 47,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon ?? Icons.arrow_forward, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(icon, size: 30, color: const Color(0xFF9BA69D)),
        const SizedBox(height: 9),
        Text(
          title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1ED),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF9D584C), fontSize: 12),
    ),
  );
}

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(10)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE8ECE7))),
);
String _firstName(String? name) => name?.split(' ').first ?? 'there';
void _showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
