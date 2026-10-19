import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';

const _green = Color(0xFF19785F);
const _ink = Color(0xFF23362C);
const _muted = Color(0xFF829087);
const _line = Color(0xFFE8ECE7);
const _dark = Color(0xFF22342B);

/// Screens 14 & 15 — the captain trip.
///
/// Screen 14: the trip progress with the single valid action for the current
/// status. Pickup and delivery confirmations require proof photos, so those
/// steps call POST /orders/:id/proof/pickup|delivery instead of a plain
/// status patch. Screen 15: the trip summary and earnings, shown once the
/// order is delivered/completed.
class CaptainTripScreen extends ConsumerStatefulWidget {
  const CaptainTripScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<CaptainTripScreen> createState() => _CaptainTripScreenState();
}

class _CaptainTripScreenState extends ConsumerState<CaptainTripScreen> {
  static const _pollInterval = Duration(seconds: 10);

  static const _statusLabels = <String, String>{
    'PENDING': 'بانتظار مندوب',
    'SEARCHING_CAPTAIN': 'جارٍ البحث عن مندوب',
    'ACCEPTED': 'تم قبول الطلب',
    'ARRIVED_AT_PICKUP': 'وصلت لموقع الاستلام',
    'PICKED_UP': 'تم استلام الشحنة',
    'ON_THE_WAY': 'الشحنة في الطريق',
    'DELIVERED': 'تم التسليم',
    'COMPLETED': 'الطلب مكتمل',
    'CANCELLED': 'تم إلغاء الطلب',
  };

  Timer? _timer;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _order = const {};
  List<dynamic> _events = const [];
  List<dynamic> _proofs = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _busy || _loading) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _status => _order['status'] as String? ?? '';

  Future<void> _load({bool silent = false}) async {
    final api = ref.read(apiClientProvider);
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.getMap('/orders/${widget.orderId}'),
        api.getList('/orders/${widget.orderId}/events'),
        api.getList('/orders/${widget.orderId}/proofs'),
      ]);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _order = results[0] as Map<String, dynamic>;
        _events = results[1] as List<dynamic>;
        _proofs = results[2] as List<dynamic>;
      });
    } catch (error) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(error);
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load(silent: true);
    } catch (error) {
      if (mounted) _toast(ApiClient.errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transition(String status) => _run(() async {
        await ref
            .read(apiClientProvider)
            .patch('/orders/${widget.orderId}/status', data: {'status': status});
        if (mounted) _toast('تم تحديث حالة الطلب');
      });

  Future<void> _submitProof(String type, String label) => _run(() async {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        await ref.read(apiClientProvider).uploadFile(
              '/orders/${widget.orderId}/proof/$type',
              bytes,
              image.name,
              field: 'photo',
            );
        if (mounted) _toast(label);
      });

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F5),
        appBar: AppBar(
          title: Text('الرحلة ${_order['reference'] ?? ''}'.trim()),
          backgroundColor: const Color(0xFFF7F8F5),
          foregroundColor: _ink,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(18),
                        children: [_errorBox(_error!)],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                        children: [
                          _statusCard(),
                          const SizedBox(height: 14),
                          _routeCard(),
                          const SizedBox(height: 14),
                          if (_status == 'DELIVERED' || _status == 'COMPLETED')
                            _summaryCard(),
                          if (_status == 'DELIVERED' || _status == 'COMPLETED')
                            const SizedBox(height: 14),
                          _timelineCard(),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final cancelled = _status == 'CANCELLED';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cancelled ? const Color(0xFFFDECEF) : _dark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                cancelled ? Icons.cancel_outlined : Icons.local_shipping_outlined,
                color: cancelled ? const Color(0xFFA03040) : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusLabels[_status] ?? _status,
                  style: TextStyle(
                    color: cancelled ? const Color(0xFFA03040) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (_status == 'DELIVERED') ...[
            const SizedBox(height: 8),
            const Text(
              'في انتظار تأكيد العميل لاستلام الشحنة لإكمال الطلب وتحويل الأرباح.',
              style: TextStyle(color: Color(0xFFC9D6CE), fontSize: 12.5),
            ),
          ],
          if (_actionLabel() != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: _busy ? null : _performAction,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(_actionLabel()!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _actionLabel() {
    switch (_status) {
      case 'ACCEPTED':
        return 'وصلت لموقع الاستلام';
      case 'ARRIVED_AT_PICKUP':
        return 'تصوير الشحنة وتأكيد الاستلام';
      case 'PICKED_UP':
        return 'بدء التوصيل للعميل';
      case 'ON_THE_WAY':
        return 'تصوير التسليم وتأكيده';
      default:
        return null;
    }
  }

  void _performAction() {
    switch (_status) {
      case 'ACCEPTED':
        _transition('ARRIVED_AT_PICKUP');
        return;
      case 'ARRIVED_AT_PICKUP':
        _submitProof('pickup', 'تم تأكيد استلام الشحنة');
        return;
      case 'PICKED_UP':
        _transition('ON_THE_WAY');
        return;
      case 'ON_THE_WAY':
        _submitProof('delivery', 'تم تأكيد تسليم الشحنة');
        return;
    }
  }

  Widget _routeCard() {
    final distance = asDoubleOrNull(_order['distanceKm']);
    return _card(
      title: 'تفاصيل الشحنة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lineRow(Icons.trip_origin, _green, 'الاستلام',
              _order['pickupLabel'] as String? ?? ''),
          const SizedBox(height: 8),
          _lineRow(Icons.place_outlined, const Color(0xFFD9534F), 'التسليم',
              _order['deliveryLabel'] as String? ?? ''),
          const Divider(height: 22),
          _infoRow('المستلم', _order['recipientName'] as String? ?? '-'),
          const SizedBox(height: 6),
          _infoRow('هاتف المستلم', _order['recipientPhone'] as String? ?? '-'),
          const SizedBox(height: 6),
          _infoRow(
            'المسافة',
            distance == null ? '-' : '${distance.toStringAsFixed(1)} كم',
          ),
          const SizedBox(height: 6),
          _infoRow('نوع الشحنة', _categoryLabel(_order['category'] as String?)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final price = asDouble(_order['price']);
    final commission = asDouble(_order['commission']);
    final completed = _status == 'COMPLETED';
    return _card(
      title: completed ? 'ملخص الرحلة والأرباح' : 'ملخص الأرباح المتوقعة',
      child: Column(
        children: [
          _infoRow('رسوم التوصيل', _egp(price)),
          const SizedBox(height: 6),
          _infoRow('عمولة الشركة', '- ${_egp(commission)}'),
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'صافي ربحك',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              Text(
                _egp(price - commission),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _green,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            completed
                ? 'تم إكمال الطلب وتحويل الأرباح صافية إلى محفظتك.'
                : 'تُخصم العمولة من المحفظة عند القبول وتُرد عند الإلغاء، والربح الصافي يُضاف بعد تأكيد العميل.',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    if (_events.isEmpty) return const SizedBox.shrink();
    final proofsByType = {
      for (final proof in _proofs)
        (proof as Map)['type'] as String? ?? '': proof,
    };
    return _card(
      title: 'سجل الرحلة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in _events.reversed) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 8, color: _green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabels[(event as Map)['toStatus'] as String? ??
                                ''] ??
                            (event['toStatus'] as String? ?? ''),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      if (event['note'] != null)
                        Text(
                          event['note'] as String,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (proofsByType.isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              'إثباتات مرفوعة: ${proofsByType.keys.map(_proofLabel).join('، ')}',
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _lineRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
              Text(value, style: const TextStyle(color: _ink)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
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
      child: Text(message, style: const TextStyle(color: Color(0xFFA03040))),
    );
  }

  String _categoryLabel(String? category) {
    const labels = <String, String>{
      'PAPERS': 'أوراق',
      'MATERIALS': 'مواد',
      'GOODS': 'بضائع',
      'SPARE_PARTS': 'قطع غيار',
      'PACKAGE': 'طرد',
      'OTHER': 'أخرى',
      'MEDICINES': 'أدوية',
      'PURCHASES': 'مشتريات',
      'FOOD': 'طعام',
      'ELECTRONICS': 'إلكترونيات',
    };
    return labels[category] ?? category ?? '-';
  }

  String _proofLabel(String type) => type == 'PICKUP' ? 'صورة الاستلام' : 'صورة التسليم';

  String _egp(double value) {
    final rounded = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return 'EGP $rounded';
  }
}
