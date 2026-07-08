import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'mock_repositories.dart';
import 'firebase_repositories.dart';

// Service Config Provider for Mock Mode (disabled, always false)
class IsMockModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) {}
}

final isMockModeProvider = NotifierProvider<IsMockModeNotifier, bool>(IsMockModeNotifier.new);

// 1. Auth Repository Interface
abstract class AuthRepository {
  Future<UserModel?> login(String email, String password);
  Future<UserModel?> registerManager(String name, String email, String password, String phone);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> forgotPassword(String email);
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> watchCurrentUser();
  Future<bool> hasManager();
}

// 2. Employee Repository Interface
abstract class EmployeeRepository {
  Stream<List<UserModel>> watchEmployees();
  Future<void> addEmployee(String name, String email, String password, String phone, String role);
  Future<void> editEmployee(UserModel employee);
  Future<void> toggleEmployeeStatus(String uid, String currentStatus);
  Future<void> resetEmployeePassword(String uid, String newPassword);
  Future<void> deleteEmployee(UserModel employee);
  Future<int> getEmployeeOrderCount(String uid);
}

// 3. Category Repository Interface
abstract class CategoryRepository {
  Stream<List<CategoryModel>> watchCategories();
  Future<void> addCategory(String name, String imageBase64, String status);
  Future<void> editCategory(CategoryModel category);
  Future<void> deleteCategory(String id);
  Future<int> getCategoryItemCount(String id);
}

// 4. Menu Repository Interface
abstract class MenuRepository {
  Stream<List<MenuItemModel>> watchMenuItems();
  Future<void> addMenuItem(MenuItemModel item);
  Future<void> editMenuItem(MenuItemModel item);
  Future<void> deleteMenuItem(String id);
  Future<int> getMenuItemOrderCount(String id);
}

// 5. Deal Repository Interface
abstract class DealRepository {
  Stream<List<DealModel>> watchDeals();
  Future<void> addDeal(DealModel deal);
  Future<void> editDeal(DealModel deal);
  Future<void> deleteDeal(String id);
}

// 6. Discount Repository Interface
abstract class DiscountRepository {
  Stream<List<DiscountModel>> watchDiscounts();
  Future<void> addDiscount(DiscountModel discount);
  Future<void> editDiscount(DiscountModel discount);
  Future<void> deleteDiscount(String id);
}

// 7. Order Repository Interface
abstract class OrderRepository {
  Stream<List<OrderModel>> watchAllOrders();
  Stream<List<OrderModel>> watchOrdersByCashier(String cashierId);
  Stream<List<OrderModel>> watchActiveOrders();
  Future<OrderModel?> getOrderById(String docId);
  Future<OrderModel?> getOrderByHumanId(String orderId);
  Future<String> placeOrder(OrderModel order);
  Future<void> updateOrderStatus(String docId, String status, String userId, String role);
  Future<void> updateOrderPaymentStatus(String docId, bool isPaid, String userId);
  Future<void> cancelOrder(String docId, String reason, String userId);
  Future<void> undoStatusChange(String docId, List<Map<String, dynamic>> previousHistory, String previousStatus);
  Future<void> updateOrderDetails(OrderModel order);
  Future<void> updateOrderRider(String docId, String riderName);
}

// 8. Settings Repository Interface
abstract class SettingsRepository {
  Future<SettingsModel> getSettings();
  Stream<SettingsModel> watchSettings();
  Future<void> saveSettings(SettingsModel settings);
}

// 9. Activity Log Repository Interface
abstract class ActivityLogRepository {
  Stream<List<ActivityLogModel>> watchActivityLogs();
  Future<void> logActivity(ActivityLogModel log);
}

// Providers declarations (implemented in mock_repositories.dart & firebase_repositories.dart)
// Keep singleton instances for persistent state across calls
final _mockAuth = MockAuthRepository();
final _mockEmp = MockEmployeeRepository();
final _mockCat = MockCategoryRepository();
final _mockMenu = MockMenuRepository();
final _mockDeal = MockDealRepository();
final _mockDisc = MockDiscountRepository();
final _mockOrd = MockOrderRepository();
final _mockSet = MockSettingsRepository();
final _mockAct = MockActivityLogRepository();

final _fbAuth = FirebaseAuthRepository();
final _fbEmp = FirebaseEmployeeRepository();
final _fbCat = FirebaseCategoryRepository();
final _fbMenu = FirebaseMenuRepository();
final _fbDeal = FirebaseDealRepository();
final _fbDisc = FirebaseDiscountRepository();
final _fbOrd = FirebaseOrderRepository();
final _fbSet = FirebaseSettingsRepository();
final _fbAct = FirebaseActivityLogRepository();

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockAuth : _fbAuth;
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockEmp : _fbEmp;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockCat : _fbCat;
});

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockMenu : _fbMenu;
});

final dealRepositoryProvider = Provider<DealRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockDeal : _fbDeal;
});

final discountRepositoryProvider = Provider<DiscountRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockDisc : _fbDisc;
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockOrd : _fbOrd;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockSet : _fbSet;
});

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockAct : _fbAct;
});

// 10. Staff Repository Interface
abstract class StaffRepository {
  Stream<List<WaiterModel>> watchWaiters();
  Future<void> addWaiter(WaiterModel waiter);
  Future<void> editWaiter(WaiterModel waiter);
  Future<void> deleteWaiter(String id);

  Stream<List<RiderModel>> watchRiders();
  Future<void> addRider(RiderModel rider);
  Future<void> editRider(RiderModel rider);
  Future<void> deleteRider(String id);
}

final _mockStaff = MockStaffRepository();
final _fbStaff = FirebaseStaffRepository();

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final isMock = ref.watch(isMockModeProvider);
  return isMock ? _mockStaff : _fbStaff;
});


