import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/views/auth_views.dart';
import '../../features/manager/presentation/views/employee_views.dart';
import '../../features/manager/presentation/views/menu_views.dart';
import '../../features/manager/presentation/views/deals_discounts_views.dart';
import '../../features/manager/presentation/views/manager_settings_reports_views.dart';
import '../../features/manager/presentation/views/manager_orders_views.dart';
import '../../features/cashier/presentation/views/cashier_views.dart';
import '../../features/cashier/presentation/views/checkout_views.dart';
import '../../features/expediter/presentation/views/expediter_views.dart';
import '../../features/manager/presentation/views/waiter_views.dart';
import '../../features/manager/presentation/views/rider_views.dart';
import '../repositories/repositories.dart';

// Stream listener to refresh GoRouter on auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authStream = ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authRepo.watchCurrentUser()),
    redirect: (context, state) async {
      final user = authStream.value;
      final path = state.uri.path;
      final loggingIn = path == '/login';
      final registering = path == '/register';
      final changingPassword = path == '/change-password';

      // 1. MANAGER REGISTER ONE-TIME CHECK
      final managerExistsCache = ref.read(managerExistsCacheProvider);
      if (!managerExistsCache) {
        try {
          final hasManager = await authRepo.hasManager();
          if (!ref.mounted) return null; // Guard against disposed provider Ref
          if (!hasManager) {
            if (!registering) return '/register';
            return null;
          } else {
            // Cache the manager existence to prevent future checks
            ref.read(managerExistsCacheProvider.notifier).state = true;
          }
        } catch (e) {
          debugPrint("Failed to check if manager exists (likely Firestore rules not setup yet): $e");
          // Fallback: let the user proceed to login/setup rather than showing a blank screen
        }
      }

      // If setup is complete and user attempts to go to Register, redirect to login
      if (registering) return '/login';

      // 2. AUTH STATUS GUARD
      if (user == null) {
        if (!loggingIn) return '/login';
        return null;
      }

      // 3. ACCOUNT STATUS CHECK
      if (user.status == 'disabled') {
        await authRepo.logout();
        return '/login';
      }

      // 4. FORCE PASSWORD CHANGE GUARD DISABLED

      // 5. ROLE ACCESS CONTROL
      if (user.role == 'manager') {
        if (loggingIn || !path.startsWith('/manager')) {
          return '/manager/dashboard';
        }
      } else if (user.role == 'cashier') {
        if (loggingIn || !path.startsWith('/cashier')) {
          return '/cashier/dashboard';
        }
      } else if (user.role == 'expediter') {
        if (loggingIn || !path.startsWith('/expediter')) {
          return '/expediter/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationView(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordView(),
      ),

      // MANAGER ROUTES
      GoRoute(
        path: '/manager/dashboard',
        builder: (context, state) => const ManagerDashboardView(),
      ),
      GoRoute(
        path: '/manager/employees',
        builder: (context, state) => const EmployeeListView(),
      ),
      GoRoute(
        path: '/manager/employees/add',
        builder: (context, state) => const EmployeeFormView(),
      ),
      GoRoute(
        path: '/manager/employees/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EmployeeFormView(employeeId: id);
        },
      ),
      GoRoute(
        path: '/manager/waiters',
        builder: (context, state) => const WaiterListView(),
      ),
      GoRoute(
        path: '/manager/riders',
        builder: (context, state) => const RiderListView(),
      ),
      GoRoute(
        path: '/manager/categories',
        builder: (context, state) => const CategoryListView(),
      ),
      GoRoute(
        path: '/manager/categories/add',
        builder: (context, state) => const CategoryFormView(),
      ),
      GoRoute(
        path: '/manager/categories/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CategoryFormView(categoryId: id);
        },
      ),
      GoRoute(
        path: '/manager/menu',
        builder: (context, state) => const MenuListView(),
      ),
      GoRoute(
        path: '/manager/menu/add',
        builder: (context, state) => const MenuItemFormView(),
      ),
      GoRoute(
        path: '/manager/menu/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MenuItemFormView(itemId: id);
        },
      ),
      GoRoute(
        path: '/manager/deals',
        builder: (context, state) => const DealListView(),
      ),
      GoRoute(
        path: '/manager/deals/add',
        builder: (context, state) => const DealFormView(),
      ),
      GoRoute(
        path: '/manager/deals/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return DealFormView(dealId: id);
        },
      ),
      GoRoute(
        path: '/manager/discounts',
        builder: (context, state) => const DiscountListView(),
      ),
      GoRoute(
        path: '/manager/discounts/add',
        builder: (context, state) => const DiscountFormView(),
      ),
      GoRoute(
        path: '/manager/discounts/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return DiscountFormView(discountId: id);
        },
      ),
      GoRoute(
        path: '/manager/orders',
        builder: (context, state) => const OrderListView(),
      ),
      GoRoute(
        path: '/manager/orders/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDetailView(orderId: id);
        },
      ),
      GoRoute(
        path: '/manager/reports',
        builder: (context, state) => const ReportsView(),
      ),
      GoRoute(
        path: '/manager/settings',
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: '/manager/profile',
        builder: (context, state) => const ProfileView(),
      ),

      // CASHIER ROUTES
      GoRoute(
        path: '/cashier/dashboard',
        builder: (context, state) => const CashierDashboardView(),
      ),
      GoRoute(
        path: '/cashier/pos',
        builder: (context, state) => const POSView(),
      ),
      GoRoute(
        path: '/cashier/checkout/customer',
        builder: (context, state) => const CheckoutCustomerView(),
      ),
      GoRoute(
        path: '/cashier/checkout/discount',
        builder: (context, state) => const CheckoutDiscountView(),
      ),
      GoRoute(
        path: '/cashier/checkout/summary',
        builder: (context, state) => const CheckoutSummaryView(),
      ),
      GoRoute(
        path: '/cashier/receipt/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ReceiptView(orderId: id);
        },
      ),
      GoRoute(
        path: '/cashier/orders',
        builder: (context, state) => const OrderTrackingView(),
      ),
      GoRoute(
        path: '/cashier/orders/search',
        builder: (context, state) => const OrderSearchView(),
      ),
      GoRoute(
        path: '/cashier/reports',
        builder: (context, state) => const CashierReportsView(),
      ),

      // EXPEDITER ROUTES
      GoRoute(
        path: '/expediter/dashboard',
        builder: (context, state) => const ExpediterDashboardView(),
      ),
      GoRoute(
        path: '/expediter/orders',
        builder: (context, state) => const OrderQueueView(),
      ),
      GoRoute(
        path: '/expediter/orders/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ExpediterOrderDetailView(orderId: id);
        },
      ),
      GoRoute(
        path: '/expediter/activity-log',
        builder: (context, state) => const ActivityHistoryView(),
      ),
    ],
  );
});
