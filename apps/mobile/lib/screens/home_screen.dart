import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class WaslnyHomeScreen extends StatefulWidget {
  const WaslnyHomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<WaslnyHomeScreen> createState() => _WaslnyHomeScreenState();
}

class _WaslnyHomeScreenState extends State<WaslnyHomeScreen> {
  static const Color bg = Color(0xFF03151D);
  static const Color card = Color(0xFF092630);
  static const Color cardLight = Color(0xFF103640);
  static const Color green = Color(0xFF00D875);
  static const Color muted = Color(0xFF9FB5BD);
  static const Color border = Color(0xFF24515B);

  int selectedTab = 0;
  String selectedParcel = 'طرود وطلبات';
  String? pickupAddress;
  String? destinationAddress;
  LatLng? pickupLocation;
  LatLng? destinationLocation;

  final List<Map<String, dynamic>> parcelTypes = [
    {
      'title': 'مشتريات',
      'icon': Icons.shopping_bag_rounded,
      'color': Color(0xFF269BFF),
    },
    {
      'title': 'طعام ومشروبات',
      'icon': Icons.lunch_dining_rounded,
      'color': Color(0xFFFFA72B),
    },
    {
      'title': 'طرود وطلبات',
      'icon': Icons.inventory_2_rounded,
      'color': Color(0xFFFFB45A),
    },
    {
      'title': 'مستندات وأوراق',
      'icon': Icons.description_rounded,
      'color': Color(0xFF8ECFFF),
    },
    {
      'title': 'أدوية',
      'icon': Icons.medical_services_rounded,
      'color': Color(0xFF55E2BC),
    },
    {
      'title': 'إلكترونيات',
      'icon': Icons.devices_rounded,
      'color': Color(0xFF7FA8FF),
    },
    {
      'title': 'هدايا',
      'icon': Icons.card_giftcard_rounded,
      'color': Color(0xFFFF697C),
    },
    {
      'title': 'أخرى',
      'icon': Icons.more_horiz_rounded,
      'color': Color(0xFFE1EAF0),
    },
  ];

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: cardLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> chooseAddress({required bool pickup}) async {
    final controller = TextEditingController(
      text: pickup ? pickupAddress : destinationAddress,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: Text(
          pickup ? 'عنوان الاستلام' : 'عنوان التسليم',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'اكتب العنوان أو اسم المكان',
            hintStyle: TextStyle(color: muted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: green),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: bg,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (pickup) {
        if (pickupAddress != result) pickupLocation = null;
        pickupAddress = result;
      } else {
        if (destinationAddress != result) destinationLocation = null;
        destinationAddress = result;
      }
    });
  }

  Future<void> chooseMapLocation({required bool pickup}) async {
    final result = await context.push<Map<String, dynamic>>(
      '/map-picker?title=${pickup ? 'مكان الاستلام' : 'مكان التسليم'}',
    );
    if (result == null || !mounted) return;
    final location = LatLng(
      (result['lat'] as num).toDouble(),
      (result['lon'] as num).toDouble(),
    );
    setState(() {
      if (pickup) {
        pickupLocation = location;
        pickupAddress ??= 'موقع محدد على الخريطة';
      } else {
        destinationLocation = location;
        destinationAddress ??= 'موقع محدد على الخريطة';
      }
    });
  }

  void startOrder() {
    if (pickupAddress == null || destinationAddress == null) {
      showMessage('أدخل عنوان الاستلام والتسليم أولاً');
      return;
    }
    if (pickupLocation == null || destinationLocation == null) {
      showMessage('حدد موقع الاستلام والتسليم على الخريطة أولاً');
      return;
    }
    final parcel = parcelTypes.firstWhere(
      (item) => item['title'] == selectedParcel,
    );
    context.push(
      '/new-order',
      extra: {
        'pickupLabel': pickupAddress,
        'pickupLatitude': pickupLocation!.latitude,
        'pickupLongitude': pickupLocation!.longitude,
        'deliveryLabel': destinationAddress,
        'deliveryLatitude': destinationLocation!.latitude,
        'deliveryLongitude': destinationLocation!.longitude,
        'category': parcel['category'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    buildHeader(),
                    const SizedBox(height: 20),
                    buildHeroBanner(),
                    const SizedBox(height: 18),
                    buildAddressCard(),
                    const SizedBox(height: 23),
                    buildSectionTitle('اختر نوع الطرد'),
                    const SizedBox(height: 13),
                    buildParcelGrid(),
                    const SizedBox(height: 20),
                    buildSafetyBanner(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          height: 49,
          width: 49,
          decoration: BoxDecoration(
            color: cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: const Icon(Icons.location_on_rounded, color: green, size: 32),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Waslny',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Orders',
                style: TextStyle(
                  fontSize: 16,
                  color: green,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => showMessage('لا توجد إشعارات جديدة'),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: cardLight,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => widget.onNavigate(2),
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget buildHeroBanner() {
    return Container(
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: border),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF124A4B), Color(0xFF06252E), Color(0xFF03151D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            right: 10,
            top: 5,
            bottom: 5,
            child: Image.asset(
              'assets/images/waslny_home_banner.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              opacity: const AlwaysStoppedAnimation(0.75),
            ),
          ),
          Positioned(
            left: 14,
            top: 17,
            child: Icon(
              Icons.location_on_rounded,
              size: 45,
              color: green.withValues(alpha: 0.65),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 23, 19, 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كل احتياجاتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'في مكان واحد',
                  style: TextStyle(
                    color: green,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'اطلب مندوب الآن واستلم طلبك\nمن مكانك إلى وجهتك.',
                  style: TextStyle(
                    color: Color(0xFFD0E0E0),
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: startOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: bg,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: const StadiumBorder(),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 20),
                        SizedBox(width: 9),
                        Text(
                          'اطلب مندوب',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget addressTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onMapTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تحديد على الخريطة',
              onPressed: onMapTap,
              icon: const Icon(Icons.map_outlined, color: green, size: 21),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          addressTile(
            icon: Icons.location_on_rounded,
            color: green,
            title: 'من',
            subtitle: pickupAddress ?? 'اختر عنوان الاستلام',
            onTap: () => chooseAddress(pickup: true),
            onMapTap: () => chooseMapLocation(pickup: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const SizedBox(width: 17),
                Container(height: 20, width: 2, color: border),
              ],
            ),
          ),
          addressTile(
            icon: Icons.location_on_rounded,
            color: const Color(0xFFFF4B64),
            title: 'إلى',
            subtitle: destinationAddress ?? 'اختر عنوان التسليم',
            onTap: () => chooseAddress(pickup: false),
            onMapTap: () => chooseMapLocation(pickup: false),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 47,
            child: ElevatedButton(
              onPressed: startOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'متابعة الطلب',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.widgets_outlined, color: green, size: 22),
      ],
    );
  }

  Widget buildParcelGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 390
            ? 2
            : constraints.maxWidth < 650
            ? 3
            : 4;
        return GridView.builder(
          itemCount: parcelTypes.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 10,
            mainAxisExtent: 128,
          ),
          itemBuilder: (context, index) {
            final item = parcelTypes[index];
            final title = item['title'] as String;
            final icon = item['icon'] as IconData;
            final color = item['color'] as Color;
            final selected = selectedParcel == title;

            return Material(
              color: selected ? const Color(0xFF103D3B) : card,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: () => setState(() => selectedParcel = title),
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected ? green : border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 45,
                        width: 45,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 29),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? green : Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 3),
                        const Icon(Icons.check_circle, color: green, size: 13),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3035), Color(0xFF08242D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: green,
              size: 31,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أمان في التوصيل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'تابع طلبك من الاستلام حتى التسليم',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 17,
          ),
        ],
      ),
    );
  }
}
