import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/manager_providers.dart';

// Helper for dates matching (using 5 AM logical day boundary)
// Only the ORDER timestamp is shifted by 5h for the business-day boundary.
// The selectedDate (from DateTime.now() or date picker) is already correct local time.
bool _isSameDay(DateTime orderTime, DateTime selectedDate) {
  final local = orderTime.toLocal();
  // Orders before 5 AM belong to the previous business day
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);
  final sel = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  return logicalDate == sel;
}

bool _isSameWeek(DateTime orderTime, DateTime selectedDate) {
  final local = orderTime.toLocal();
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);

  final startOfWeek = DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
      .subtract(Duration(days: selectedDate.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));

  return (logicalDate.isAtSameMomentAs(startOfWeek) || logicalDate.isAfter(startOfWeek)) &&
      (logicalDate.isAtSameMomentAs(endOfWeek) || logicalDate.isBefore(endOfWeek));
}

bool _isSameMonth(DateTime orderTime, DateTime selectedDate) {
  final local = orderTime.toLocal();
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);
  return logicalDate.year == selectedDate.year && logicalDate.month == selectedDate.month;
}

bool _isSameYear(DateTime orderTime, DateTime selectedDate) {
  final local = orderTime.toLocal();
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);
  return logicalDate.year == selectedDate.year;
}

// --- Manager Dashboard Screen (Home) ---
class ManagerDashboardView extends ConsumerWidget {
  const ManagerDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final ordersState = ref.watch(allOrdersStreamProvider);
    final employeesState = ref.watch(employeesStreamProvider);
    final isMock = ref.watch(isMockModeProvider);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: "Boss Food Corner POS - Manager",
        userName: currentUser.name,
        userRole: currentUser.role,
        isMockMode: isMock,
        onMockToggle: (val) {
          ref.read(isMockModeProvider.notifier).state = val;
        },
        onLogout: () {
          ref.read(authActionProvider.notifier).logout();
        },
        onProfilePressed: () => context.go('/manager/profile'),
      ),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Initializing manager dashboard..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(allOrdersStreamProvider)),
        data: (orders) {
          final employees = employeesState.value ?? [];
          final today = DateTime.now();

          // Calculate KPI aggregates for Today
          final todayOrders = orders.where((o) => _isSameDay(o.createdAt, today) && o.status != "Cancelled").toList();
          final todayRevenue = todayOrders.fold<double>(0, (sum, o) => sum + (o.status == "Completed" ? o.grandTotal : 0));
          final pendingCount = orders.where((o) => o.status == "Pending").length;
          final prepCount = orders.where((o) => o.status == "In Preparation").length;
          final readyCount = orders.where((o) => o.status == "Ready").length;
          final completedToday = orders.where((o) => _isSameDay(o.createdAt, today) && o.status == "Completed").length;
          final handoverToday = orders.where((o) => _isSameDay(o.createdAt, today) && o.status == "Handover").length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back, ${currentUser.name}!",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here is what's happening at your restaurant today.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // KPI Summaries Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossCount = width > 1200 ? 4 : (width > 800 ? 2 : 1);
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.3,
                      ),
                      children: [
                        SummaryCard(
                          label: "TODAY'S REVENUE",
                          value: "Rs. ${todayRevenue.toStringAsFixed(2)}",
                          icon: Icons.monetization_on,
                          color: Colors.green,
                        ),
                        SummaryCard(
                          label: "TOTAL ORDERS TODAY",
                          value: "${todayOrders.length} Orders",
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                        ),
                        SummaryCard(
                          label: "PENDING ORDERS",
                          value: "$pendingCount Queue",
                          icon: Icons.hourglass_empty,
                          color: pendingCount > 0 ? Colors.red : Colors.grey,
                          iconColor: pendingCount > 0 ? Colors.red : Colors.grey,
                        ),
                        SummaryCard(
                          label: "IN PREPARATION",
                          value: "$prepCount Kitchen",
                          icon: Icons.restaurant,
                          color: Colors.orange,
                        ),
                        SummaryCard(
                          label: "READY FOR PICKUP",
                          value: "$readyCount Orders",
                          icon: Icons.check_circle_outline,
                          color: Colors.teal,
                        ),
                        SummaryCard(
                          label: "COMPLETED TODAY",
                          value: "$completedToday Handed Over",
                          icon: Icons.done_all,
                          color: Colors.blue.shade800,
                        ),
                        SummaryCard(
                          label: "HANDOVER TODAY",
                          value: "$handoverToday Unpaid Orders",
                          icon: Icons.handshake_outlined,
                          color: Colors.deepPurple,
                        ),
                        SummaryCard(
                          label: "ACTIVE EMPLOYEES",
                          value: "${employees.length} Staff",
                          icon: Icons.people_outline,
                          color: Colors.purple,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Quick Actions
                const Text(
                  "Operational Controls & Settings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildQuickActionButton(
                      context,
                      label: "Configure Menu",
                      icon: Icons.restaurant_menu,
                      color: AppTheme.primaryColor,
                      onPressed: () => context.go('/manager/menu'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Setup Categories",
                      icon: Icons.category,
                      color: AppTheme.secondaryColor,
                      textColor: Colors.black,
                      onPressed: () => context.go('/manager/categories'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Manage Employees",
                      icon: Icons.people,
                      color: Colors.blue.shade700,
                      onPressed: () => context.go('/manager/employees'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Manage Waiters",
                      icon: Icons.restaurant,
                      color: Colors.orange.shade700,
                      onPressed: () => context.go('/manager/waiters'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Manage Riders",
                      icon: Icons.delivery_dining,
                      color: Colors.pink.shade700,
                      onPressed: () => context.go('/manager/riders'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Bundle Deals",
                      icon: Icons.local_offer,
                      color: Colors.purple.shade700,
                      onPressed: () => context.go('/manager/deals'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Campaign Discounts",
                      icon: Icons.discount,
                      color: Colors.teal.shade700,
                      onPressed: () => context.go('/manager/discounts'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Order History",
                      icon: Icons.history,
                      color: Colors.indigo.shade700,
                      onPressed: () => context.go('/manager/orders'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Sales Analytics Reports",
                      icon: Icons.analytics_outlined,
                      color: Colors.green.shade700,
                      onPressed: () => context.go('/manager/reports'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "POS Settings",
                      icon: Icons.settings,
                      color: Colors.grey.shade800,
                      onPressed: () => context.go('/manager/settings'),
                    ),
                    _buildQuickActionButton(
                      context,
                      label: "Daily Sales Details",
                      icon: Icons.summarize,
                      color: Colors.amber.shade900,
                      onPressed: () => context.go('/manager/daily-details'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 220,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: MaterialThemeBypass(
        color: color,
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bypass theme inkwell wrapper
class MaterialThemeBypass extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback onPressed;

  const MaterialThemeBypass({
    super.key,
    required this.color,
    required this.child,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

// --- Manager Settings View ---
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _taxController = TextEditingController();
  final _passwordController = TextEditingController();
  double _deliveryCharges = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _taxController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loadSettings() async {
    final settings = await ref.read(settingsRepositoryProvider).getSettings();
    _phoneController.text = settings.phoneNumber;
    _deliveryCharges = settings.deliveryCharges;
    _taxController.text = settings.taxRate.toString();
    _passwordController.text = settings.cashierReportPassword;
  }

  void _showError(String err) {
    String cleanErr = err.replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanErr),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();
      final tax = double.parse(_taxController.text);
      final pass = _passwordController.text.trim();

      final settings = SettingsModel(
        id: "default",
        phoneNumber: phone,
        deliveryCharges: _deliveryCharges,
        taxRate: tax,
        updatedAt: DateTime.now(),
        cashierReportPassword: pass,
      );

      try {
        await ref.read(managerActionProvider.notifier).saveSettings(settings);
        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Restaurant settings updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/manager/dashboard');
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(managerActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Configure Restaurant POS Rules",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      CustomTextField(
                        label: "Tax Rate (%)",
                        placeholder: "e.g., 5.0",
                        controller: _taxController,
                        prefixIcon: Icons.percent,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Tax rate is required";
                          final doubleVal = double.tryParse(val);
                          if (doubleVal == null || doubleVal < 0 || doubleVal > 100) return "Must be between 0 and 100";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Cashier Reports Password",
                        placeholder: "Enter password (or leave empty to disable)",
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) => null,
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: "SAVE SETTINGS",
                        isLoading: actionState.isLoading,
                        onPressed: _onSave,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        "Manage Daily Closing",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<DailyClosingModel?>(
                        stream: ref.read(orderRepositoryProvider).watchDailyClosing(
                          DateFormat('yyyy-MM-dd').format(
                            DateTime.now().hour < 5
                                ? DateTime.now().subtract(const Duration(days: 1))
                                : DateTime.now()
                          )
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final closing = snapshot.data;
                          if (closing == null) {
                            return const Center(
                              child: Text(
                                "Today's closing has not been submitted yet.",
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            );
                          }
                          if (closing.isReleased) {
                            return const Center(
                              child: Text(
                                "Today's closing is currently released (unlocked for cashier edits).",
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Today's closing is SUBMITTED and locked.",
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              CustomButton(
                                text: "RELEASE DAILY CLOSING",
                                color: Colors.orange,
                                onPressed: () async {
                                  final dateStr = DateFormat('yyyy-MM-dd').format(
                                    DateTime.now().hour < 5
                                        ? DateTime.now().subtract(const Duration(days: 1))
                                        : DateTime.now()
                                  );
                                  try {
                                    await ref.read(orderRepositoryProvider).releaseDailyClosing(dateStr);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Daily closing released successfully!"), backgroundColor: Colors.green),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "CANCEL",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/manager/dashboard'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Manager Profile Screen ---
class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _passFormKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        _nameController.text = user.name;
        _phoneController.text = user.phone;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showError(String err) {
    String cleanErr = err.replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanErr),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onUpdateProfile() async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final updated = user.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      try {
        await ref.read(managerActionProvider.notifier).editEmployee(updated);
        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          _showSuccess("Profile updated successfully!");
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _onChangePassword() async {
    if (_passFormKey.currentState!.validate()) {
      final current = _currentController.text;
      final newPass = _newController.text;

      try {
        await ref.read(authActionProvider.notifier).changePassword(current, newPass);
        final actState = ref.read(authActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          _currentController.clear();
          _newController.clear();
          _confirmController.clear();
          _showSuccess("Password updated successfully!");
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final actState = ref.watch(managerActionProvider);
    final authActionState = ref.watch(authActionProvider);

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                
                final profileCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(Icons.person, color: Colors.white, size: 48),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            user.role.toUpperCase(),
                            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(height: 32),
                          CustomTextField(
                            label: "Email Address (Read Only)",
                            controller: TextEditingController(text: user.email),
                            prefixIcon: Icons.email,
                            readOnly: true,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Manager Full Name",
                            placeholder: "e.g., John Doe",
                            controller: _nameController,
                            prefixIcon: Icons.badge_outlined,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Name is required";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Support Phone Number",
                            placeholder: "e.g., 03001234567",
                            controller: _phoneController,
                            prefixIcon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Phone number is required";
                              final clean = val.trim();
                              if (clean.length != 11 || !clean.startsWith("03") || double.tryParse(clean) == null) {
                                return "Enter a valid 11 digit Pakistani number (03XXXXXXXXX)";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          CustomButton(
                            text: "SAVE PROFILE CHANGES",
                            isLoading: actState.isLoading,
                            onPressed: _onUpdateProfile,
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final passwordCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _passFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock_outline, color: AppTheme.secondaryColor, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            "Change Password",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(height: 32),
                          CustomTextField(
                            label: "Current Password",
                            placeholder: "Enter current password",
                            controller: _currentController,
                            isPassword: true,
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Current password is required";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "New Password (min 6 chars)",
                            placeholder: "Choose new password",
                            controller: _newController,
                            isPassword: true,
                            validator: (val) {
                              if (val == null || val.isEmpty) return "New password is required";
                              if (val.length < 6) return "Must be at least 6 characters";
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: "Confirm New Password",
                            placeholder: "Match new password",
                            controller: _confirmController,
                            isPassword: true,
                            validator: (val) {
                              if (val != _newController.text) return "Passwords do not match";
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          CustomButton(
                            text: "CHANGE PASSWORD",
                            isLoading: authActionState.isLoading,
                            onPressed: _onChangePassword,
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      profileCard,
                      const SizedBox(height: 24),
                      passwordCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: profileCard),
                    const SizedBox(width: 24),
                    Expanded(child: passwordCard),
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}

// --- Sales Reports Screen ---
class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(allOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Reports Analytics"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.secondaryColor,
          tabs: const [
            Tab(text: "Daily Reports"),
            Tab(text: "Weekly Reports"),
            Tab(text: "Monthly Reports"),
            Tab(text: "Yearly Reports"),
          ],
        ),
      ),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Compiling financial aggregates..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          // Tab 0: Daily
          final dailyOrders = orders.where((o) => _isSameDay(o.createdAt, _selectedDate)).toList();
          // Tab 1: Weekly
          final weeklyOrders = orders.where((o) => _isSameWeek(o.createdAt, _selectedDate)).toList();
          // Tab 2: Monthly
          final monthlyOrders = orders.where((o) => _isSameMonth(o.createdAt, _selectedDate)).toList();
          // Tab 3: Yearly
          final yearlyOrders = orders.where((o) => _isSameYear(o.createdAt, _selectedDate)).toList();

          // Calculate start and end of week (Monday to Sunday) for the weekly report label
          final startOfWeek = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
              .subtract(Duration(days: _selectedDate.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          final weeklyLabel = "${DateFormat.yMMMd().format(startOfWeek)} - ${DateFormat.yMMMd().format(endOfWeek)}";

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportSection(dailyOrders, "Daily Summary", DateFormat.yMMMMd().format(_selectedDate), _selectDateDialog),
              _buildReportSection(weeklyOrders, "Weekly Summary", weeklyLabel, _selectDateDialog),
              _buildReportSection(monthlyOrders, "Monthly Summary", DateFormat.y().add_MMMM().format(_selectedDate), _selectMonthDialog),
              _buildReportSection(yearlyOrders, "Yearly Summary", DateFormat.y().format(_selectedDate), _selectYearDialog),
            ],
          );
        },
      ),
    );
  }

  void _selectDateDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectMonthDialog() async {
    // Standard Flutter DatePicker restricted to Month
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectYearDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildReportSection(List<OrderModel> orders, String title, String dateLabel, VoidCallback onDateSelect) {
    final completed = orders.where((o) => o.status == "Completed").toList();
    final cancelled = orders.where((o) => o.status == "Cancelled").toList();

    final double revenue = completed.fold(0, (sum, o) => sum + o.grandTotal);
    final double tax = completed.fold(0, (sum, o) => sum + o.tax);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("Selected Period: $dateLabel", style: TextStyle(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CustomButton(
                text: "Select Date Range",
                onPressed: onDateSelect,
                size: 'small',
                icon: Icons.calendar_month,
              )
            ],
          ),
          const SizedBox(height: 24),

          // Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: w > 1200 ? 4 : (w > 800 ? 2 : 1),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.2,
                ),
                children: [
                  SummaryCard(
                    label: "NET REVENUE",
                    value: "Rs. ${revenue.toStringAsFixed(2)}",
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                  SummaryCard(
                    label: "ORDERS COMPLETED",
                    value: "${completed.length} Orders",
                    icon: Icons.shopping_basket,
                    color: Colors.blue,
                  ),
                  SummaryCard(
                    label: "CANCELLED ORDERS",
                    value: "${cancelled.length} Orders",
                    icon: Icons.cancel_presentation_outlined,
                    color: Colors.red,
                  ),
                  SummaryCard(
                    label: "TAXES COLLECTED",
                    value: "Rs. ${tax.toStringAsFixed(2)}",
                    icon: Icons.receipt,
                    color: Colors.teal,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          if (completed.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: Text(
                  "No sales activity recorded for this period.",
                  style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ] else ...[
            // fl_chart Visualizations
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                
                Widget leftWidget;
                if (title == "Daily Summary") {
                  leftWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Completed Orders Summary",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: completed.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final o = completed[index];
                          final timeStr = DateFormat('hh:mm a').format(o.createdAt);
                          final itemsList = o.items.map((item) => "${item.quantity}x ${item.name}").toList();
                          final dealsList = o.deals.map((d) => "1x Bundle: ${d['name']}").toList();
                          final itemsSummary = [...itemsList, ...dealsList].join(', ');
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Text(
                                "#${o.orderId.substring(o.orderId.length - 2)}",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                            title: Text("${o.customerName} (${o.orderType.toUpperCase()})"),
                            subtitle: Text("Order ID: ${o.orderId} [Token: ${o.tokenId ?? '000'}]\nTime: $timeStr • Items: $itemsSummary"),
                            trailing: Text(
                              "Rs. ${o.grandTotal.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                } else if (title == "Weekly Summary") {
                  // Weekly Sales Grouping
                  Map<int, double> daySales = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
                  Map<int, int> dayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
                  for (var o in completed) {
                    final logical = o.createdAt.subtract(const Duration(hours: 5));
                    final weekday = logical.weekday;
                    daySales[weekday] = (daySales[weekday] ?? 0.0) + o.grandTotal;
                    dayCounts[weekday] = (dayCounts[weekday] ?? 0) + 1;
                  }
                  final weekdaysNames = {
                    1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday",
                    5: "Friday", 6: "Saturday", 7: "Sunday"
                  };
                  leftWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Weekly Sales Breakdown",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 7,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final dayNum = index + 1;
                          final sales = daySales[dayNum] ?? 0.0;
                          final count = dayCounts[dayNum] ?? 0;
                          final name = weekdaysNames[dayNum] ?? "";
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("$count Orders placed"),
                            trailing: Text(
                              "Rs. ${sales.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                } else if (title == "Monthly Summary") {
                  // Monthly Sales Grouping
                  Map<int, double> dateSales = {};
                  Map<int, int> dateCounts = {};
                  for (var o in completed) {
                    final logical = o.createdAt.subtract(const Duration(hours: 5));
                    final day = logical.day;
                    dateSales[day] = (dateSales[day] ?? 0.0) + o.grandTotal;
                    dateCounts[day] = (dateCounts[day] ?? 0) + 1;
                  }
                  final sortedDays = dateSales.keys.toList()..sort();
                  final monthLabel = DateFormat('MMMM').format(_selectedDate);
                  
                  leftWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Monthly Sales Breakdown ($monthLabel)",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      sortedDays.isEmpty
                          ? const Text("No sales recorded.")
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sortedDays.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final day = sortedDays[index];
                                final sales = dateSales[day] ?? 0.0;
                                final count = dateCounts[day] ?? 0;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                    child: Text("$day", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  ),
                                  title: Text("$monthLabel $day", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text("$count Orders placed"),
                                  trailing: Text(
                                    "Rs. ${sales.toStringAsFixed(0)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                );
                              },
                            ),
                    ],
                  );
                } else {
                  // Yearly Summary
                  Map<int, double> monthSales = {};
                  Map<int, int> monthCounts = {};
                  for (int m = 1; m <= 12; m++) {
                    monthSales[m] = 0.0;
                    monthCounts[m] = 0;
                  }
                  for (var o in completed) {
                    final logical = o.createdAt.subtract(const Duration(hours: 5));
                    final m = logical.month;
                    monthSales[m] = (monthSales[m] ?? 0.0) + o.grandTotal;
                    monthCounts[m] = (monthCounts[m] ?? 0) + 1;
                  }
                  final monthNames = {
                    1: "January", 2: "February", 3: "March", 4: "April", 5: "May", 6: "June",
                    7: "July", 8: "August", 9: "September", 10: "October", 11: "November", 12: "December"
                  };
                  
                  leftWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Yearly Sales Breakdown",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 12,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final mNum = index + 1;
                          final sales = monthSales[mNum] ?? 0.0;
                          final count = monthCounts[mNum] ?? 0;
                          final name = monthNames[mNum] ?? "";
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Text(name.substring(0, 3), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("$count Orders placed"),
                            trailing: Text(
                              "Rs. ${sales.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }

                final leftCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: leftWidget,
                  ),
                );

                final rightCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Distribution by Order Type",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(completed),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftCard,
                      const SizedBox(height: 24),
                      rightCard,
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: leftCard),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: rightCard),
                    ],
                  );
                }
              },
            ),
          ]
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<OrderModel> orders) {
    int dineIn = orders.where((o) => o.orderType == "dine-in").length;
    int takeaway = orders.where((o) => o.orderType == "takeaway").length;
    int delivery = orders.where((o) => o.orderType == "delivery").length;

    int total = dineIn + takeaway + delivery;
    if (total == 0) return [];

    double dineInPerc = (dineIn / total) * 100;
    double takeawayPerc = (takeaway / total) * 100;
    double deliveryPerc = (delivery / total) * 100;

    return [
      if (dineIn > 0)
        PieChartSectionData(
          color: Colors.blue,
          value: dineIn.toDouble(),
          title: "Dine-In\n${dineInPerc.toStringAsFixed(0)}%",
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (takeaway > 0)
        PieChartSectionData(
          color: Colors.orange,
          value: takeaway.toDouble(),
          title: "Takeaway\n${takeawayPerc.toStringAsFixed(0)}%",
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (delivery > 0)
        PieChartSectionData(
          color: Colors.teal,
          value: delivery.toDouble(),
          title: "Delivery\n${deliveryPerc.toStringAsFixed(0)}%",
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];
  }
}
