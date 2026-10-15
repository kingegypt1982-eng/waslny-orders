import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';

const _reviewGreen = Color(0xFF19785F);
const _reviewInk = Color(0xFF23362C);
const _reviewMuted = Color(0xFF829087);

class OrderReviewScreen extends ConsumerStatefulWidget {
  const OrderReviewScreen({
    super.key,
    required this.orderData,
    required this.quote,
  });

  final Map<String, dynamic> orderData;
  final Map<String, dynamic> quote;

  @override
  ConsumerState<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends ConsumerState<OrderReviewScreen> {
  bool _busy = false;

  Future<void> _confirmOrder() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final order = await ref
          .read(apiClientProvider)
          .post('/orders', data: widget.orderData);
      final orderId = order['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw StateError('Order response did not include an id');
      }
      if (mounted) context.go('/track/$orderId');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) return 'انتهت الجلسة، سجّل الدخول مرة أخرى';
      if (statusCode == 400) {
        final response = error.response?.data;
        final message = response is Map ? response['message'] : null;
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
        if (message is String && message.trim().isNotEmpty) return message;
        return 'بيانات الطلب غير صالحة. راجعها وحاول مرة أخرى.';
      }
      if (error.response == null &&
          (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout)) {
        return 'تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى.';
      }
    }
    return 'تعذر إنشاء الطلب. حاول مرة أخرى.';
  }

  String _categoryLabel(Object? category) => switch (category) {
    'PURCHASES' => 'مشتريات',
    'FOOD' => 'طعام ومشروبات',
    'PACKAGE' => 'طرود وطلبات',
    'PAPERS' => 'مستندات وأوراق',
    'MEDICINES' => 'أدوية',
    'ELECTRONICS' => 'إلكترونيات',
    'GOODS' => 'هدايا',
    'SPARE_PARTS' => 'قطع غيار',
    _ => 'شحنة',
  };

  String _amount(Object? value) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    return number?.toStringAsFixed(2) ?? '--';
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.quote['currency']?.toString() ?? '';
    final price = _amount(widget.quote['price']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراجعة السعر'),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _ReviewSection(
                children: [
                  _ReviewRow(
                    label: 'نقطة الاستلام',
                    value: widget.orderData['pickupLabel']?.toString() ?? '—',
                    icon: Icons.trip_origin,
                  ),
                  const Divider(height: 24),
                  _ReviewRow(
                    label: 'نقطة التسليم',
                    value: widget.orderData['deliveryLabel']?.toString() ?? '—',
                    icon: Icons.location_on_outlined,
                  ),
                  const Divider(height: 24),
                  _ReviewRow(
                    label: 'نوع الشحنة',
                    value: _categoryLabel(widget.orderData['category']),
                    icon: Icons.inventory_2_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ReviewSection(
                children: [
                  _ReviewRow(
                    label: 'المسافة',
                    value: '${widget.quote['distanceKm'] ?? '—'} كم',
                    icon: Icons.route_outlined,
                  ),
                  const Divider(height: 24),
                  _ReviewRow(
                    label: 'رسوم التوصيل',
                    value: '$price $currency',
                    icon: Icons.local_shipping_outlined,
                  ),
                  const Divider(height: 24),
                  _ReviewRow(
                    label: 'الإجمالي',
                    value: '$price $currency',
                    icon: Icons.receipt_long_outlined,
                    emphasize: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _confirmOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _reviewGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _reviewGreen.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'تأكيد وطلب مندوب',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : () => context.pop(),
                child: const Text('تعديل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE6EBE6)),
    ),
    child: Column(children: children),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _reviewGreen, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _reviewMuted,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            color: _reviewInk,
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 17 : 14,
          ),
        ),
      ),
    ],
  );
}
