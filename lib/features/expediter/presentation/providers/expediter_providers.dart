import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../../core/widgets/shared_widgets.dart'; // import triggerBeepNotification
import '../../../auth/presentation/providers/auth_providers.dart';

// FIFO Stream of active queue orders (oldest first) - kept alive for instant tab switching
final expediterQueueStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  ref.keepAlive();
  final repo = ref.watch(orderRepositoryProvider);
  return repo.watchActiveOrders().map((list) {
    // Sort FIFO (oldest first)
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  });
});

// Local timestamp tracking when the expediter last viewed incoming pending orders
class LastViewedIncomingTimestampNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  @override
  set state(DateTime value) => super.state = value;
}

final lastViewedIncomingTimestampProvider = NotifierProvider<LastViewedIncomingTimestampNotifier, DateTime>(LastViewedIncomingTimestampNotifier.new);

// Unread pending orders count
final unreadIncomingCountProvider = Provider.autoDispose<int>((ref) {
  final activeOrders = ref.watch(expediterQueueStreamProvider).value ?? [];
  final lastViewed = ref.watch(lastViewedIncomingTimestampProvider);

  return activeOrders.where((o) {
    return o.status == "Pending" && o.createdAt.isAfter(lastViewed);
  }).length;
});

class ExpediterActionNotifier extends Notifier<AsyncValue<void>> {
  Set<String> _knownOrderIds = {};

  @override
  AsyncValue<void> build() {
    // Subscribe to active queue to automatically trigger sound chime on new pending arrivals
    ref.listen<AsyncValue<List<OrderModel>>>(expediterQueueStreamProvider, (prev, next) {
      if (next.hasValue) {
        final currentIds = next.value!.map((o) => o.id).toSet();
        if (_knownOrderIds.isNotEmpty) {
          final newIds = currentIds.difference(_knownOrderIds);
          // If there is any brand new order and it is Pending, play browser beep alert
          final hasNewPending = next.value!.any((o) => newIds.contains(o.id) && o.status == "Pending");
          if (hasNewPending) {
            triggerBeepNotification();
          }
        }
        _knownOrderIds = currentIds;
      }
    });

    return const AsyncValue.data(null);
  }

  Future<void> updateStatus(String docId, String newStatus, String role) async {
    state = const AsyncValue.loading();

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception("User unauthenticated");

      await ref.read(orderRepositoryProvider).updateOrderStatus(docId, newStatus, user.uid, role);

      if (ref.mounted) {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      if (ref.mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final expediterActionProvider = NotifierProvider<ExpediterActionNotifier, AsyncValue<void>>(() {
  return ExpediterActionNotifier();
});
