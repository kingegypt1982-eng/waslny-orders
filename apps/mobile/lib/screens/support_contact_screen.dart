import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for contacting support about issues with a captain or order
class SupportContactScreen extends ConsumerWidget {
  final String? orderId;
  final String? captainId;
  final String? issueType; // 'captain_behavior', 'late_delivery', 'communication_issue', etc.
  final String? description;

  const SupportContactScreen({
    super.key,
    this.orderId,
    this.captainId,
    this.issueType,
    this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _formKey = GlobalKey<FormState>();
    final _issueController = TextEditingController();
    final _descriptionController = TextEditingController();

    // Initialize controllers with existing values if provided
    if (description != null) {
      _descriptionController.text = description!;
    }
    if (issueType != null) {
      _issueController.text = issueType!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تواصل مع الدعم'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order and captain info
              if (orderId != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات الطلب',
                        style: TextStyle(
                          color: Colors.indigo,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('معرف الطلب', orderId ?? '—'),
                      _buildInfoRow('معرف الكابتن', captainId ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Issue type selection
              const Text(
                'نوع المشكله',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _issueController.text.isNotEmpty ? _issueController.text : null,
                decoration: InputDecoration(
                  hintText: 'حدد نوع المشكله',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'communication_issue',
                    child: Text('مشكلة في التواصل'),
                  ),
                  DropdownMenuItem(
                    value: 'late_delivery',
                    child: Text('تأخر في التسليم'),
                  ),
                  DropdownMenuItem(
                    value: 'captain_behavior',
                    child: Text('سلوك الكابتن'),
                  ),
                  DropdownMenuItem(
                    value: 'vehicle_issue',
                    child: Text('مشكلة في المركبة'),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('أخرى'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _issueController.text = value;
                  }
                },
              ),
              const SizedBox(height: 24),

              // Description field
              const Text(
                'وصف التفاصيل',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'صف بالتفصيل المشكلة التي واجهتها',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال وصف المشكلة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Send support request
                    _showSuccessDialog(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'إرسال البلاغ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم الإرسال'),
        content: const Text('تم إرسال البلاغ بنجاح لفريق الدعم. سنتواصل معك قريباً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    ).then((_) {
      // Navigate back after dialog is closed
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }
}