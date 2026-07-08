import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';

// --- STREAMS ---
// keepAlive streams: menu, categories, deals, discounts, waiters, riders, settings
// These are accessed on multiple screens and rarely change — keeping them alive
// avoids re-fetching from Firestore on every navigation.

final employeesStreamProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.watch(employeeRepositoryProvider).watchEmployees();
});

final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  ref.keepAlive();
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

final menuItemsStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  ref.keepAlive();
  return ref.watch(menuRepositoryProvider).watchMenuItems();
});

final dealsStreamProvider = StreamProvider<List<DealModel>>((ref) {
  ref.keepAlive();
  return ref.watch(dealRepositoryProvider).watchDeals();
});

final discountsStreamProvider = StreamProvider<List<DiscountModel>>((ref) {
  ref.keepAlive();
  return ref.watch(discountRepositoryProvider).watchDiscounts();
});

final allOrdersStreamProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).watchAllOrders();
});

final settingsStreamProvider = StreamProvider<SettingsModel>((ref) {
  ref.keepAlive();
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

final activityLogsStreamProvider = StreamProvider.autoDispose<List<ActivityLogModel>>((ref) {
  return ref.watch(activityLogRepositoryProvider).watchActivityLogs();
});

final waitersStreamProvider = StreamProvider<List<WaiterModel>>((ref) {
  ref.keepAlive();
  return ref.watch(staffRepositoryProvider).watchWaiters();
});

final ridersStreamProvider = StreamProvider<List<RiderModel>>((ref) {
  ref.keepAlive();
  return ref.watch(staffRepositoryProvider).watchRiders();
});

// --- ACTION NOTIFIERS ---

class ManagerActionNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> _safeAction(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      if (ref.mounted) {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      if (ref.mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  // Employee actions
  Future<void> addEmployee(String name, String email, String password, String phone, String role) async {
    await _safeAction(() => ref.read(employeeRepositoryProvider).addEmployee(name, email, password, phone, role));
  }

  Future<void> editEmployee(UserModel employee) async {
    await _safeAction(() => ref.read(employeeRepositoryProvider).editEmployee(employee));
  }

  Future<void> toggleEmployeeStatus(String uid, String currentStatus) async {
    await _safeAction(() => ref.read(employeeRepositoryProvider).toggleEmployeeStatus(uid, currentStatus));
  }

  Future<void> resetEmployeePassword(String uid, String newPassword) async {
    await _safeAction(() => ref.read(employeeRepositoryProvider).resetEmployeePassword(uid, newPassword));
  }

  Future<void> deleteEmployee(UserModel employee) async {
    await _safeAction(() => ref.read(employeeRepositoryProvider).deleteEmployee(employee));
  }

  // Category actions
  Future<void> addCategory(String name, String imageBase64, String status) async {
    await _safeAction(() => ref.read(categoryRepositoryProvider).addCategory(name, imageBase64, status));
  }

  Future<void> editCategory(CategoryModel category) async {
    await _safeAction(() => ref.read(categoryRepositoryProvider).editCategory(category));
  }

  Future<void> deleteCategory(String id) async {
    await _safeAction(() async {
      final hasItems = await ref.read(categoryRepositoryProvider).getCategoryItemCount(id);
      if (hasItems > 0) {
        throw Exception("This category contains $hasItems items. Deleting will leave these items without category.");
      }
      await ref.read(categoryRepositoryProvider).deleteCategory(id);
    });
  }

  // Menu actions
  Future<void> addMenuItem(MenuItemModel item) async {
    await _safeAction(() => ref.read(menuRepositoryProvider).addMenuItem(item));
  }

  Future<void> editMenuItem(MenuItemModel item) async {
    await _safeAction(() => ref.read(menuRepositoryProvider).editMenuItem(item));
  }

  Future<void> deleteMenuItem(String id) async {
    await _safeAction(() => ref.read(menuRepositoryProvider).deleteMenuItem(id));
  }

  // Deal actions
  Future<void> addDeal(DealModel deal) async {
    await _safeAction(() => ref.read(dealRepositoryProvider).addDeal(deal));
  }

  Future<void> editDeal(DealModel deal) async {
    await _safeAction(() => ref.read(dealRepositoryProvider).editDeal(deal));
  }

  Future<void> deleteDeal(String id) async {
    await _safeAction(() => ref.read(dealRepositoryProvider).deleteDeal(id));
  }

  // Discount actions
  Future<void> addDiscount(DiscountModel discount) async {
    await _safeAction(() => ref.read(discountRepositoryProvider).addDiscount(discount));
  }

  Future<void> editDiscount(DiscountModel discount) async {
    await _safeAction(() => ref.read(discountRepositoryProvider).editDiscount(discount));
  }

  Future<void> deleteDiscount(String id) async {
    await _safeAction(() => ref.read(discountRepositoryProvider).deleteDiscount(id));
  }

  // Settings action
  Future<void> saveSettings(SettingsModel settings) async {
    await _safeAction(() => ref.read(settingsRepositoryProvider).saveSettings(settings));
  }

  // Order actions (Manager/Cashier can cancel)
  Future<void> cancelOrder(String docId, String reason, String userId) async {
    await _safeAction(() => ref.read(orderRepositoryProvider).cancelOrder(docId, reason, userId));
  }

  // Waiter actions
  Future<void> addWaiter(WaiterModel waiter) async {
    await _safeAction(() => ref.read(staffRepositoryProvider).addWaiter(waiter));
  }

  Future<void> editWaiter(WaiterModel waiter) async {
    await _safeAction(() => ref.read(staffRepositoryProvider).editWaiter(waiter));
  }

  Future<void> deleteWaiter(String id) async {
    await _safeAction(() => ref.read(staffRepositoryProvider).deleteWaiter(id));
  }

  // Rider actions
  Future<void> addRider(RiderModel rider) async {
    await _safeAction(() => ref.read(staffRepositoryProvider).addRider(rider));
  }

  Future<void> editRider(RiderModel rider) async {
    await _safeAction(() => ref.read(staffRepositoryProvider).editRider(rider));
  }

  Future<void> deleteRider(String id) async {
    await _safeAction(() => ref.read(staffRepositoryProvider).deleteRider(id));
  }
}

final managerActionProvider = NotifierProvider<ManagerActionNotifier, AsyncValue<void>>(() {
  return ManagerActionNotifier();
});
