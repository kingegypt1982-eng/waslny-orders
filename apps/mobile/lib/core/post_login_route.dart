import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_client.dart';

/// Statuses where the captain has an unfinished trip and must land on it.
const captainActiveTripStatuses = <String>{
  'ACCEPTED',
  'ARRIVED_AT_PICKUP',
  'PICKED_UP',
  'ON_THE_WAY',
};

/// Single source of truth for "where do I go after signing in?".
///
/// A fresh captain sign-up still goes through the documents wizard. Existing
/// captains are restored to an active trip when one exists; pending/rejected/
/// suspended captains land on `/`, which renders the approval panel (including
/// the rejection reason and document-edit button). Clients go home.
Future<String> resolveLandingRoute(
  ApiClient api,
  Map<String, dynamic> user, {
  bool freshCaptainRegistration = false,
}) async {
  final role = user['role']?.toString().toUpperCase();
  if (role == 'CAPTAIN' && freshCaptainRegistration) {
    return '/captain-documents';
  }
  if (role != 'CAPTAIN') return '/';

  try {
    final profile = await api.getMap('/captains/me');
    final status = profile['status']?.toString().toUpperCase();
    if (status != null && status != 'ACTIVE') return '/';

    final orders = await api.getList('/orders');
    for (final entry in orders) {
      if (entry is! Map) continue;
      final order = Map<String, dynamic>.from(entry);
      final id = order['id']?.toString();
      final orderStatus = order['status']?.toString().toUpperCase();
      if (id != null &&
          id.isNotEmpty &&
          captainActiveTripStatuses.contains(orderStatus)) {
        return '/captain/trip/$id';
      }
    }
  } catch (_) {
    // A profile/order lookup failure must never block sign-in.
  }
  return '/';
}

/// Navigates using [resolveLandingRoute], ignoring results after disposal.
Future<void> goToLandingRoute(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> user, {
  bool freshCaptainRegistration = false,
}) async {
  final route = await resolveLandingRoute(
    ref.read(apiClientProvider),
    user,
    freshCaptainRegistration: freshCaptainRegistration,
  );
  if (context.mounted) context.go(route);
}
