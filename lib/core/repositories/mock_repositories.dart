import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'repositories.dart';

// Safe Base64 transparent 1x1 PNG fallback string
const String kPlaceholderBase64 = 
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==";

class MockDatabase {
  static int lastToken = 0;
  static String lastDate = "";

  static final List<UserModel> users = [
    // Pre-created employee accounts for easy logging in
    UserModel(
      uid: "cashier1",
      name: "Ahmed Cashier",
      email: "cashier@boss.com",
      phone: "03001234567",
      role: "cashier",
      status: "active",
      forcePasswordChange: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    UserModel(
      uid: "expediter1",
      name: "Ali Expediter",
      email: "expediter@boss.com",
      phone: "03112233445",
      role: "expediter",
      status: "active",
      forcePasswordChange: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  static final List<CategoryModel> categories = [
    CategoryModel(
      id: "cat_burgers",
      name: "Burgers",
      imageBase64: kPlaceholderBase64,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryModel(
      id: "cat_pizza",
      name: "Pizza",
      imageBase64: kPlaceholderBase64,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryModel(
      id: "cat_sides",
      name: "Sides & Fries",
      imageBase64: kPlaceholderBase64,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryModel(
      id: "cat_drinks",
      name: "Beverages",
      imageBase64: kPlaceholderBase64,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<MenuItemModel> menuItems = [
    MenuItemModel(
      id: "item_zinger",
      name: "Zinger Burger",
      categoryId: "cat_burgers",
      description: "Crispy chicken breast with fresh lettuce and mayo in a soft bun.",
      price: 450.0,
      imageBase64: kPlaceholderBase64,
      prepTime: 12,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MenuItemModel(
      id: "item_cheese_burger",
      name: "Double Cheese Burger",
      categoryId: "cat_burgers",
      description: "Double flame-grilled beef patties with cheddar cheese and special sauce.",
      price: 550.0,
      imageBase64: kPlaceholderBase64,
      prepTime: 15,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MenuItemModel(
      id: "item_pizza_tikka",
      name: "Chicken Tikka Pizza (M)",
      categoryId: "cat_pizza",
      description: "Traditional Tikka chicken, cheese, onions, and tomato sauce.",
      price: 950.0,
      imageBase64: kPlaceholderBase64,
      prepTime: 20,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MenuItemModel(
      id: "item_fries",
      name: "Loaded Cheese Fries",
      categoryId: "cat_sides",
      description: "Golden fries topped with warm melted cheese sauce and jalapenos.",
      price: 320.0,
      imageBase64: kPlaceholderBase64,
      prepTime: 8,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    MenuItemModel(
      id: "item_coke",
      name: "Coca Cola Can",
      categoryId: "cat_drinks",
      description: "330ml chilled soft drink.",
      price: 120.0,
      imageBase64: kPlaceholderBase64,
      prepTime: 1,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<DealModel> deals = [
    DealModel(
      id: "deal_zinger_combo",
      name: "Zinger Combo Deal",
      price: 500.0,
      itemIds: ["item_zinger", "item_coke"],
      imageBase64: kPlaceholderBase64,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<DiscountModel> discounts = [
    DiscountModel(
      id: "disc_student",
      name: "Student Discount",
      type: "percentage",
      value: 10.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DiscountModel(
      id: "disc_flat",
      name: "Flat Discount",
      type: "fixed",
      value: 100.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<OrderModel> orders = [];
  static final List<DailyClosingModel> dailyClosings = [];
  static final List<ActivityLogModel> activityLogs = [];

  static final List<WaiterModel> waiters = [
    WaiterModel(id: "waiter_1", name: "Waiter Kamran", status: "active", createdAt: DateTime.now().subtract(const Duration(days: 10))),
    WaiterModel(id: "waiter_2", name: "Waiter Asif", status: "active", createdAt: DateTime.now().subtract(const Duration(days: 10))),
  ];

  static final List<RiderModel> riders = [
    RiderModel(id: "rider_1", name: "Rider Bilal", phone: "03009876543", status: "active", createdAt: DateTime.now().subtract(const Duration(days: 10))),
    RiderModel(id: "rider_2", name: "Rider Shafi", phone: "03123456789", status: "active", createdAt: DateTime.now().subtract(const Duration(days: 10))),
  ];

  static SettingsModel restaurantSettings = SettingsModel(
    id: "default",
    phoneNumber: "03001234567",
    deliveryCharges: 50.0,
    taxRate: 5.0,
    updatedAt: DateTime.now(),
    cashierReportPassword: "",
    accountDetails: "",
  );

  static int orderIdCounter = 42; // Starts from 42 as per receipt spec example
}

// Controller Streams to notify listeners on edits
final _usersStreamController = StreamController<List<UserModel>>.broadcast();
final _categoriesStreamController = StreamController<List<CategoryModel>>.broadcast();
final _menuItemsStreamController = StreamController<List<MenuItemModel>>.broadcast();
final _dealsStreamController = StreamController<List<DealModel>>.broadcast();
final _discountsStreamController = StreamController<List<DiscountModel>>.broadcast();
final _waitersStreamController = StreamController<List<WaiterModel>>.broadcast();
final _ridersStreamController = StreamController<List<RiderModel>>.broadcast();

void _triggerWaitersUpdate() {
  _waitersStreamController.add(List<WaiterModel>.from(MockDatabase.waiters));
}

void _triggerRidersUpdate() {
  _ridersStreamController.add(List<RiderModel>.from(MockDatabase.riders));
}
final _ordersStreamController = StreamController<List<OrderModel>>.broadcast();
final _activityLogsStreamController = StreamController<List<ActivityLogModel>>.broadcast();
final _settingsStreamController = StreamController<SettingsModel>.broadcast();
final _currentUserStreamController = StreamController<UserModel?>.broadcast();

void _triggerUsersUpdate() => _usersStreamController.add(List.from(MockDatabase.users));
void _triggerCategoriesUpdate() => _categoriesStreamController.add(List.from(MockDatabase.categories));
void _triggerMenuItemsUpdate() => _menuItemsStreamController.add(List.from(MockDatabase.menuItems));
void _triggerDealsUpdate() => _dealsStreamController.add(List.from(MockDatabase.deals));
void _triggerDiscountsUpdate() => _discountsStreamController.add(List.from(MockDatabase.discounts));
void _triggerOrdersUpdate() => _ordersStreamController.add(List.from(MockDatabase.orders));
void _triggerActivityLogsUpdate() => _activityLogsStreamController.add(List.from(MockDatabase.activityLogs));
void _triggerSettingsUpdate() => _settingsStreamController.add(MockDatabase.restaurantSettings);

final _dailyClosingStreamControllers = <String, StreamController<DailyClosingModel?>>{};

StreamController<DailyClosingModel?> _getClosingController(String date) {
  return _dailyClosingStreamControllers.putIfAbsent(date, () => StreamController<DailyClosingModel?>.broadcast());
}

void _triggerClosingUpdate(String date) {
  final idx = MockDatabase.dailyClosings.indexWhere((c) => c.id == date);
  final closing = idx != -1 ? MockDatabase.dailyClosings[idx] : null;
  _getClosingController(date).add(closing);
}

// --- Implementation Classes ---

class MockAuthRepository implements AuthRepository {
  UserModel? _currentUser;

  @override
  Future<UserModel?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final matchingUser = MockDatabase.users.firstWhere(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
      orElse: () => throw Exception("User not found or invalid credentials"),
    );

    if (matchingUser.status == "disabled") {
      throw Exception("Your account has been disabled. Please contact your manager.");
    }

    _currentUser = matchingUser;
    _currentUserStreamController.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<UserModel?> registerManager(String name, String email, String password, String phone) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final managerExists = MockDatabase.users.any((u) => u.role == "manager");
    if (managerExists) {
      throw Exception("Manager account already configured.");
    }

    final newManager = UserModel(
      uid: "manager_uid_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      email: email,
      phone: phone,
      role: "manager",
      status: "active",
      forcePasswordChange: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    MockDatabase.users.add(newManager);
    _currentUser = newManager;
    _currentUserStreamController.add(_currentUser);
    _triggerUsersUpdate();
    return newManager;
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentUser == null) throw Exception("Not logged in");
    
    // In mock repository, just reset forcePasswordChange status
    final index = MockDatabase.users.indexWhere((u) => u.uid == _currentUser!.uid);
    if (index != -1) {
      MockDatabase.users[index] = MockDatabase.users[index].copyWith(
        forcePasswordChange: false,
        updatedAt: DateTime.now(),
      );
      _currentUser = MockDatabase.users[index];
      _currentUserStreamController.add(_currentUser);
      _triggerUsersUpdate();
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final matchingUser = MockDatabase.users.firstWhere(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
      orElse: () => throw Exception("No account registered with this email."),
    );
    if (matchingUser.role != "manager") {
      throw Exception("Please contact your manager to reset your password.");
    }
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _currentUserStreamController.add(null);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Stream<UserModel?> watchCurrentUser() {
    return _currentUserStreamController.stream;
  }

  @override
  Future<bool> hasManager() async {
    return MockDatabase.users.any((u) => u.role == "manager");
  }
}

class MockEmployeeRepository implements EmployeeRepository {
  @override
  Stream<List<UserModel>> watchEmployees() {
    // Immediate first emit
    Timer.run(() => _triggerUsersUpdate());
    return _usersStreamController.stream;
  }

  @override
  Future<void> addEmployee(String name, String email, String password, String phone, String role) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final emailExists = MockDatabase.users.any((u) => u.email.toLowerCase() == email.toLowerCase().trim());
    if (emailExists) {
      throw Exception("Email address is already in use by another employee.");
    }

    final newEmployee = UserModel(
      uid: "emp_uid_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      email: email,
      phone: phone,
      role: role,
      status: "active",
      forcePasswordChange: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    MockDatabase.users.add(newEmployee);
    _triggerUsersUpdate();
  }

  @override
  Future<void> editEmployee(UserModel employee) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.users.indexWhere((u) => u.uid == employee.uid);
    if (index != -1) {
      MockDatabase.users[index] = employee.copyWith(updatedAt: DateTime.now());
      _triggerUsersUpdate();
    }
  }

  @override
  Future<void> toggleEmployeeStatus(String uid, String currentStatus) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = MockDatabase.users.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final newStatus = currentStatus == "active" ? "disabled" : "active";
      MockDatabase.users[index] = MockDatabase.users[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      _triggerUsersUpdate();
    }
  }

  @override
  Future<void> resetEmployeePassword(String uid, String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.users.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      MockDatabase.users[index] = MockDatabase.users[index].copyWith(
        forcePasswordChange: false,
        updatedAt: DateTime.now(),
      );
      _triggerUsersUpdate();
    }
  }

  @override
  Future<void> deleteEmployee(UserModel employee) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.users.removeWhere((u) => u.uid == employee.uid);
    _triggerUsersUpdate();
  }

  @override
  Future<int> getEmployeeOrderCount(String uid) async {
    return MockDatabase.orders.where((o) => o.cashierId == uid).length;
  }
}

class MockCategoryRepository implements CategoryRepository {
  @override
  Stream<List<CategoryModel>> watchCategories() {
    Timer.run(() => _triggerCategoriesUpdate());
    return _categoriesStreamController.stream;
  }

  @override
  Future<void> addCategory(String name, String imageBase64, String status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final exists = MockDatabase.categories.any((c) => c.name.toLowerCase() == name.trim().toLowerCase());
    if (exists) throw Exception("Category name already exists.");

    final newCat = CategoryModel(
      id: "cat_uid_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      imageBase64: imageBase64,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    MockDatabase.categories.add(newCat);
    _triggerCategoriesUpdate();
  }

  @override
  Future<void> editCategory(CategoryModel category) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      MockDatabase.categories[index] = category.copyWith(updatedAt: DateTime.now());
      _triggerCategoriesUpdate();
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.categories.removeWhere((c) => c.id == id);
    _triggerCategoriesUpdate();
  }

  @override
  Future<int> getCategoryItemCount(String id) async {
    return MockDatabase.menuItems.where((i) => i.categoryId == id).length;
  }
}

class MockMenuRepository implements MenuRepository {
  @override
  Stream<List<MenuItemModel>> watchMenuItems() {
    Timer.run(() => _triggerMenuItemsUpdate());
    return _menuItemsStreamController.stream;
  }

  @override
  Future<void> addMenuItem(MenuItemModel item) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final exists = MockDatabase.menuItems.any((m) => m.name.toLowerCase() == item.name.trim().toLowerCase());
    if (exists) throw Exception("Menu item name already exists.");

    final newItem = item.copyWith(
      id: "menu_uid_${DateTime.now().millisecondsSinceEpoch}",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    MockDatabase.menuItems.add(newItem);
    _triggerMenuItemsUpdate();
  }

  @override
  Future<void> editMenuItem(MenuItemModel item) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.menuItems.indexWhere((m) => m.id == item.id);
    if (index != -1) {
      MockDatabase.menuItems[index] = item.copyWith(updatedAt: DateTime.now());
      _triggerMenuItemsUpdate();
    }
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.menuItems.removeWhere((m) => m.id == id);
    _triggerMenuItemsUpdate();
  }

  @override
  Future<int> getMenuItemOrderCount(String id) async {
    int count = 0;
    for (var o in MockDatabase.orders) {
      for (var item in o.items) {
        if (item.menuItemId == id) count++;
      }
    }
    return count;
  }
}

class MockDealRepository implements DealRepository {
  @override
  Stream<List<DealModel>> watchDeals() {
    Timer.run(() => _triggerDealsUpdate());
    return _dealsStreamController.stream;
  }

  @override
  Future<void> addDeal(DealModel deal) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final exists = MockDatabase.deals.any((d) => d.name.toLowerCase() == deal.name.trim().toLowerCase());
    if (exists) throw Exception("Deal name already exists.");

    final newDeal = deal.copyWith(
      id: "deal_uid_${DateTime.now().millisecondsSinceEpoch}",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    MockDatabase.deals.add(newDeal);
    _triggerDealsUpdate();
  }

  @override
  Future<void> editDeal(DealModel deal) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.deals.indexWhere((d) => d.id == deal.id);
    if (index != -1) {
      MockDatabase.deals[index] = deal.copyWith(updatedAt: DateTime.now());
      _triggerDealsUpdate();
    }
  }

  @override
  Future<void> deleteDeal(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.deals.removeWhere((d) => d.id == id);
    _triggerDealsUpdate();
  }
}

class MockDiscountRepository implements DiscountRepository {
  @override
  Stream<List<DiscountModel>> watchDiscounts() {
    Timer.run(() => _triggerDiscountsUpdate());
    return _discountsStreamController.stream;
  }

  @override
  Future<void> addDiscount(DiscountModel discount) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final exists = MockDatabase.discounts.any((d) => d.name.toLowerCase() == discount.name.trim().toLowerCase());
    if (exists) throw Exception("Discount name already exists.");

    final newDisc = discount.copyWith(
      id: "disc_uid_${DateTime.now().millisecondsSinceEpoch}",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    MockDatabase.discounts.add(newDisc);
    _triggerDiscountsUpdate();
  }

  @override
  Future<void> editDiscount(DiscountModel discount) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.discounts.indexWhere((d) => d.id == discount.id);
    if (index != -1) {
      MockDatabase.discounts[index] = discount.copyWith(updatedAt: DateTime.now());
      _triggerDiscountsUpdate();
    }
  }

  @override
  Future<void> deleteDiscount(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.discounts.removeWhere((d) => d.id == id);
    _triggerDiscountsUpdate();
  }
}

class MockOrderRepository implements OrderRepository {
  @override
  Stream<List<OrderModel>> watchAllOrders() {
    Timer.run(() => _triggerOrdersUpdate());
    return _ordersStreamController.stream;
  }

  @override
  Stream<List<OrderModel>> watchOrdersByCashier(String cashierId) {
    return _ordersStreamController.stream.map(
      (list) {
        final filtered = list.where((o) => o.cashierId == cashierId).toList();
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return filtered;
      },
    );
  }

  @override
  Stream<List<OrderModel>> watchActiveOrders() {
    Timer.run(() => _triggerOrdersUpdate());
    return _ordersStreamController.stream.map(
      (list) => list.where((o) => o.status != "Completed" && o.status != "Cancelled" && o.status != "Handover").toList(),
    );
  }

  @override
  Stream<OrderModel?> watchOrderById(String docId) {
    return _ordersStreamController.stream.map((list) {
      try {
        return list.firstWhere((o) => o.id == docId);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<OrderModel?> getOrderById(String docId) async {
    try {
      return MockDatabase.orders.firstWhere((o) => o.id == docId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OrderModel?> getOrderByHumanId(String orderId) async {
    try {
      return MockDatabase.orders.firstWhere((o) => o.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> placeOrder(OrderModel order) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.orderIdCounter++;
    final formattedId = MockDatabase.orderIdCounter.toString().padLeft(6, '0');
    final docId = "ord_uid_${DateTime.now().millisecondsSinceEpoch}";

    final logicalToday = DateTime.now().subtract(const Duration(hours: 5));
    final dateStr = DateFormat('yyyy-MM-dd').format(logicalToday);
    if (MockDatabase.lastDate != dateStr) {
      MockDatabase.lastToken = 1;
      MockDatabase.lastDate = dateStr;
    } else {
      MockDatabase.lastToken++;
    }
    final formattedTokenId = MockDatabase.lastToken.toString().padLeft(3, '0');

    final newOrder = order.copyWith(
      id: docId,
      orderId: formattedId,
      tokenId: formattedTokenId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      statusHistory: [
        { 'status': 'Pending', 'timestamp': DateTime.now(), 'updatedBy': order.cashierId }
      ]
    );

    MockDatabase.orders.add(newOrder);
    _triggerOrdersUpdate();
    return docId;
  }

  @override
  Future<void> updateOrderDetails(OrderModel order) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      final existing = MockDatabase.orders[index];
      final history = List<Map<String, dynamic>>.from(existing.statusHistory);
      history.add({
        'status': '${existing.status} (Edited)',
        'timestamp': DateTime.now(),
        'updatedBy': order.cashierId,
      });

      MockDatabase.orders[index] = order.copyWith(
        statusHistory: history,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _triggerOrdersUpdate();
    }
  }

  @override
  Future<void> updateOrderStatus(String docId, String status, String userId, String role) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.orders.indexWhere((o) => o.id == docId);
    if (index != -1) {
      final oldStatus = MockDatabase.orders[index].status;
      final updatedHistory = List<Map<String, dynamic>>.from(MockDatabase.orders[index].statusHistory);
      updatedHistory.add({
        'status': status,
        'timestamp': DateTime.now(),
        'updatedBy': userId,
      });

      MockDatabase.orders[index] = MockDatabase.orders[index].copyWith(
        status: status,
        statusHistory: updatedHistory,
        updatedAt: DateTime.now(),
      );

      // Log activity if changed by Expediter
      if (role == "expediter") {
        final employee = MockDatabase.users.firstWhere((u) => u.uid == userId, orElse: () => MockDatabase.users[0]);
        final log = ActivityLogModel(
          id: "log_uid_${DateTime.now().millisecondsSinceEpoch}",
          orderId: MockDatabase.orders[index].orderId,
          previousStatus: oldStatus,
          newStatus: status,
          expediterId: userId,
          expediterName: employee.name,
          timestamp: DateTime.now(),
        );
        MockDatabase.activityLogs.add(log);
        _triggerActivityLogsUpdate();
      }

      _triggerOrdersUpdate();
    }
  }

  @override
  Future<void> updateOrderPaymentStatus(String docId, bool isPaid, String userId, {double? amountReceived, double? change}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = MockDatabase.orders.indexWhere((o) => o.id == docId);
    if (index != -1) {
      final order = MockDatabase.orders[index];
      final history = List<Map<String, dynamic>>.from(order.statusHistory);
      String newStatus = order.status;
      
      if (!isPaid && order.status == "Completed") {
        newStatus = "Handover";
        history.add({
          'status': 'Handover',
          'timestamp': DateTime.now(),
          'updatedBy': userId,
        });
      } else if (isPaid && order.status == "Handover") {
        newStatus = "Completed";
        history.add({
          'status': 'Completed',
          'timestamp': DateTime.now(),
          'updatedBy': userId,
        });
      }
      
      MockDatabase.orders[index] = order.copyWith(
        isPaid: isPaid,
        status: newStatus,
        statusHistory: history,
        amountReceived: amountReceived ?? order.amountReceived,
        change: change ?? order.change,
        updatedAt: DateTime.now(),
      );
      _triggerOrdersUpdate();
    }
  }

  @override
  Future<void> cancelOrder(String docId, String reason, String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = MockDatabase.orders.indexWhere((o) => o.id == docId);
    if (index != -1) {
      final updatedHistory = List<Map<String, dynamic>>.from(MockDatabase.orders[index].statusHistory);
      updatedHistory.add({
        'status': 'Cancelled',
        'timestamp': DateTime.now(),
        'updatedBy': userId,
      });

      MockDatabase.orders[index] = MockDatabase.orders[index].copyWith(
        status: "Cancelled",
        statusHistory: updatedHistory,
        cancellationReason: reason,
        cancelledAt: DateTime.now(),
        cancelledBy: userId,
        updatedAt: DateTime.now(),
      );

      _triggerOrdersUpdate();
    }
  }

  @override
  Future<void> undoStatusChange(String docId, List<Map<String, dynamic>> previousHistory, String previousStatus) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = MockDatabase.orders.indexWhere((o) => o.id == docId);
    if (index != -1) {
      MockDatabase.orders[index] = MockDatabase.orders[index].copyWith(
        status: previousStatus,
        statusHistory: previousHistory,
        updatedAt: DateTime.now(),
      );
      
      // Clean up the last activity log if one was added
      final humanId = MockDatabase.orders[index].orderId;
      MockDatabase.activityLogs.removeWhere((l) => l.orderId == humanId && l.timestamp.isAfter(DateTime.now().subtract(const Duration(seconds: 40))));
      _triggerActivityLogsUpdate();
      _triggerOrdersUpdate();
    }
  }

  @override
  Future<void> updateOrderRider(String docId, String riderName) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = MockDatabase.orders.indexWhere((o) => o.id == docId);
    if (index != -1) {
      MockDatabase.orders[index] = MockDatabase.orders[index].copyWith(
        riderName: riderName,
        updatedAt: DateTime.now(),
      );
      _triggerOrdersUpdate();
    }
  }

  @override
  Stream<DailyClosingModel?> watchDailyClosing(String date) {
    Timer.run(() => _triggerClosingUpdate(date));
    return _getClosingController(date).stream;
  }

  @override
  Future<void> saveDailyClosing(DailyClosingModel closing) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = MockDatabase.dailyClosings.indexWhere((c) => c.id == closing.id);
    if (idx != -1) {
      MockDatabase.dailyClosings[idx] = closing;
    } else {
      MockDatabase.dailyClosings.add(closing);
    }
    _triggerClosingUpdate(closing.id);
  }

  @override
  Future<void> releaseDailyClosing(String date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = MockDatabase.dailyClosings.indexWhere((c) => c.id == date);
    if (idx != -1) {
      MockDatabase.dailyClosings[idx] = MockDatabase.dailyClosings[idx].copyWith(isReleased: true);
      _triggerClosingUpdate(date);
    }
  }
}

class MockSettingsRepository implements SettingsRepository {
  @override
  Future<SettingsModel> getSettings() async {
    return MockDatabase.restaurantSettings;
  }

  @override
  Stream<SettingsModel> watchSettings() {
    Timer.run(() => _triggerSettingsUpdate());
    return _settingsStreamController.stream;
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    await Future.delayed(const Duration(milliseconds: 500));
    MockDatabase.restaurantSettings = settings.copyWith(updatedAt: DateTime.now());
    _triggerSettingsUpdate();
  }
}

class MockActivityLogRepository implements ActivityLogRepository {
  @override
  Stream<List<ActivityLogModel>> watchActivityLogs() {
    Timer.run(() => _triggerActivityLogsUpdate());
    return _activityLogsStreamController.stream;
  }

  @override
  Future<void> logActivity(ActivityLogModel log) async {
    MockDatabase.activityLogs.add(log);
    _triggerActivityLogsUpdate();
  }
}

class MockStaffRepository implements StaffRepository {
  @override
  Stream<List<WaiterModel>> watchWaiters() {
    Timer.run(() => _triggerWaitersUpdate());
    return _waitersStreamController.stream;
  }

  @override
  Future<void> addWaiter(WaiterModel waiter) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newWaiter = waiter.copyWith(id: "waiter_${DateTime.now().millisecondsSinceEpoch}");
    MockDatabase.waiters.add(newWaiter);
    _triggerWaitersUpdate();
  }

  @override
  Future<void> editWaiter(WaiterModel waiter) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = MockDatabase.waiters.indexWhere((w) => w.id == waiter.id);
    if (idx != -1) {
      MockDatabase.waiters[idx] = waiter;
      _triggerWaitersUpdate();
    }
  }

  @override
  Future<void> deleteWaiter(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDatabase.waiters.removeWhere((w) => w.id == id);
    _triggerWaitersUpdate();
  }

  @override
  Stream<List<RiderModel>> watchRiders() {
    Timer.run(() => _triggerRidersUpdate());
    return _ridersStreamController.stream;
  }

  @override
  Future<void> addRider(RiderModel rider) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newRider = rider.copyWith(id: "rider_${DateTime.now().millisecondsSinceEpoch}");
    MockDatabase.riders.add(newRider);
    _triggerRidersUpdate();
  }

  @override
  Future<void> editRider(RiderModel rider) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = MockDatabase.riders.indexWhere((r) => r.id == rider.id);
    if (idx != -1) {
      MockDatabase.riders[idx] = rider;
      _triggerRidersUpdate();
    }
  }

  @override
  Future<void> deleteRider(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    MockDatabase.riders.removeWhere((r) => r.id == id);
    _triggerRidersUpdate();
  }
}
