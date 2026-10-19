import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../screens.dart' show availableOrdersProvider, captainLocationProvider;

const _green = Color(0xFF19785F);
const _ink = Color(0xFF23362C);
const _muted = Color(0xFF829087);
const _line = Color(0xFFE8ECE7);

/// Screens 12 & 13 — captain availability.
///
/// Screen 12: the online/offline switch plus the service radius inside the
/// band the admin configured (`radiusBand` from GET /captains/me).
/// Screen 13: the nearby-orders feed with price, distance, accept and skip,
/// refreshed every 5 seconds while the screen is open.
class CaptainAvailabilityScreen extends ConsumerStatefulWidget {
  const CaptainAvailabilityScreen({super.key});

  @override
  ConsumerState<CaptainAvailabilityScreen> createState() =>
      _CaptainAvailabilityScreenState();
}

class _CaptainAvailabilityScreenState
    extends ConsumerState<CaptainAvailabilityScreen> {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _isOnline = false;
  double _radiusKm = 10;
  double _minRadius = 2;
  double _maxRadius = 15;
  List<Map<String, dynamic>> _orders = const [];
  final Set<String> _busyOrders = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _saving || _loading) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final api = ref.read(apiClientProvider);
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final point = ref.read(captainLocationProvider);
      final results = await Future.wait([
        api.getMap('/captains/me'),
        api.getList(
          '/orders/available',
          query: {'latitude': point.latitude, 'longitude': point.longitude},
        ),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final band = profile['radiusBand'];
      final orders = (results[1] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      setState(() {
        _loading = false;
        _error = null;
        _isOnline = profile['isOnline'] as bool? ?? false;
        _radiusKm =
            (profile['serviceRadiusKm'] as num?)?.toDouble() ?? _radiusKm;
        if (band is Map) {
          _minRadius = (band['min'] as num?)?.toDouble() ?? _minRadius;
          _maxRadius = (band['max'] as num?)?.toDouble() ?? _maxRadius;
        }
        _orders = orders;
      });
      ref.invalidate(availableOrdersProvider);
    } catch (error) {
      if (!mounted) return;
      if (silent) return; // keep the last good data while polling
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(error);
      });
    }
  }

  Future<void> _save({bool? online, double? radiusKm}) async {
    final api = ref.read(apiClientProvider);
    final previousOnline = _isOnline;
    final previousRadius = _radiusKm;
    setState(() {
      _saving = true;
      if (online != null) _isOnline = online;
      if (radiusKm != null) _radiusKm = radiusKm;
    });
    try {
      final body = <String, dynamic>{'isOnline': online ?? _isOnline};
      if (radiusKm != null) body['serviceRadiusKm'] = radiusKm;
      await api.patch('/captains/me/availability', data: body);
      if (!mounted) return;
      _toast(online == false ? 'تم إيقاف استقبال الطلبات' : 'تم تحديث حالة التوفر');
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isOnline = previousOnline;
        _radiusKm = previousRadius;
      });
      _toast(ApiClient.errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> order) async {
    final id = order['id'] as String;
    setState(() => _busyOrders.add(id));
    try {
      await ref.read(apiClientProvider).post('/orders/$id/accept');
      if (!mounted) return;
      ref.invalidate(availableOrdersProvider);
      _toast('تم قبول الطلب، بالتوفيق!');
      context.push('/captain/trip/$id');
    } catch (error) {
      if (!mounted) return;
      _toast(ApiClient.errorMessage(error));
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _busyOrders.remove(id));
    }
  }

  Future<void> _skip(Map<String, dynamic> order) async {
    final id = order['id'] as String;
    setState(() => _busyOrders.add(id));
    try {
      await ref.read(apiClientProvider).post('/orders/$id/skip');
      if (!mounted) return;
      setState(() =>
          _orders = _orders.where((item) => item['id'] != id).toList());
      ref.invalidate(availableOrdersProvider);
      _toast('تم تخطي الطلب');
    } catch (error) {
      if (!mounted) return;
      _toast(ApiClient.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busyOrders.remove(id));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final point = ref.watch(captainLocationProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F5),
        appBar: AppBar(
          title: const Text('حالة التوفر والطلبات القريبة'),
          backgroundColor: const Color(0xFFF7F8F5),
          foregroundColor: _ink,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              children: [
                _availabilityCard(),
                const SizedBox(height: 14),
                _locationLine(point.latitude, point.longitude),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الطلبات القريبة (${_orders.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _ink,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('تحديث'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _errorBox(_error!)
                else if (!_isOnline)
                  _emptyState(
                    Icons.power_settings_new,
                    'أنت غير متصل الآن',
                    'فعّل «متصل» ليظهر لك الطلبات القريبة.',
                  )
                else if (_orders.isEmpty)
                  _emptyState(
                    Icons.near_me_outlined,
                    'لا توجد طلبات قريبة',
                    'سيظهر هنا أي طلب جديد داخل نطاق خدمتك.',
                  )
                else
                  for (final order in _orders) _orderCard(order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _availabilityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isOnline ? const Color(0xFF00A868) : _muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isOnline
                      ? 'متصل — تصلك الطلبات القريبة'
                      : 'غير متصل — لن تصلك طلبات',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Switch(
                value: _isOnline,
                activeThumbColor: _green,
                onChanged: _saving ? null : (value) => _save(online: value),
              ),
            ],
          ),
          const Divider(height: 22),
          Text(
            'نطاق الخدمة: ${_radiusKm.toStringAsFixed(0)} كم',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            'يظهر لك فقط الطلبات داخل هذا النطاق (المسموح من '
            '${_minRadius.toStringAsFixed(0)} إلى ${_maxRadius.toStringAsFixed(0)} كم).',
            style: const TextStyle(fontSize: 12.5, color: _muted),
          ),
          Slider(
            value: _radiusKm.clamp(_minRadius, _maxRadius).toDouble(),
            min: _minRadius,
            max: _maxRadius,
            divisions: (_maxRadius - _minRadius).round().clamp(1, 100).toInt(),
            label: '${_radiusKm.toStringAsFixed(0)} كم',
            activeColor: _green,
            onChanged: _saving
                ? null
                : (value) => setState(() => _radiusKm = value),
            onChangeEnd: (value) => _save(radiusKm: value),
          ),
        ],
      ),
    );
  }

  Widget _locationLine(double latitude, double longitude) {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 16, color: _muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'موقعك الحالي: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
            style: const TextStyle(fontSize: 12.5, color: _muted),
          ),
        ),
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = order['id'] as String;
    final busy = _busyOrders.contains(id);
    final distance = (order['distanceToPickupKm'] as num?)?.toDouble();
    final price = (order['price'] as num?)?.toDouble() ?? 0;
    final commission = (order['commission'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
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
                _egp(price),
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (distance != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.near_me_outlined, size: 14, color: _muted),
                const SizedBox(width: 6),
                Text(
                  '${distance.toStringAsFixed(1)} كم من موقعك',
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _routeLine(order),
          const SizedBox(height: 10),
          Text(
            'صافي ربحك: ${_egp(price - commission)}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _skip(order),
                  icon: const Icon(Icons.close, size: 17),
                  label: const Text('تخطي'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  onPressed: busy ? null : () => _accept(order),
                  icon: const Icon(Icons.check, size: 17),
                  label: Text(busy ? 'جارٍ...' : 'قبول الطلب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeLine(Map<String, dynamic> order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trip_origin, size: 14, color: _green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order['pickupLabel'] as String? ?? '',
                style: const TextStyle(color: _ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.place_outlined, size: 14, color: Color(0xFFD9534F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order['deliveryLabel'] as String? ?? '',
                style: const TextStyle(color: _ink),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5C2CB)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFA03040)),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: _muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  String _egp(double value) {
    final rounded = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return 'EGP $rounded';
  }
}
