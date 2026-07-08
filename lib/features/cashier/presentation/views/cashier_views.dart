import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../manager/presentation/providers/manager_providers.dart';
import '../providers/cashier_providers.dart';
import 'checkout_views.dart'; // import step widgets if needed
import '../../../manager/presentation/views/menu_views.dart'; // import buildBase64Image

// --- CASHIER DASHBOARD SCREEN ---
class CashierDashboardView extends ConsumerWidget {
  const CashierDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final ordersState = ref.watch(cashierOrdersStreamProvider);
    final isMock = ref.watch(isMockModeProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: "Boss Food Corner POS - Cashier Dashboard",
        userName: user.name,
        userRole: user.role,
        isMockMode: isMock,
        onMockToggle: (val) {
          ref.read(isMockModeProvider.notifier).state = val;
        },
        onLogout: () {
          ref.read(authActionProvider.notifier).logout();
        },
      ),
      bottomNavigationBar: _buildBottomNav(context, 0),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Initializing Cashier workspace..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          final today = DateTime.now();
          final activeOrders = orders.where((o) => o.status == "Pending" || o.status == "In Preparation" || o.status == "Ready" || o.status == "Handover").toList();
          final todayCompleted = orders.where((o) => _isSameDay(o.createdAt, today) && o.status == "Completed").toList();
          final todayHandover = orders.where((o) => _isSameDay(o.createdAt, today) && o.status == "Handover").toList();
          final todayRevenue = todayCompleted.fold<double>(0, (sum, o) => sum + o.grandTotal);

          // Recent 5 orders
          final recentOrders = orders.take(5).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Responsive layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: isNarrow ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Welcome, ${user.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            const Text("Manage active shifts and checkout menu orders.", style: TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        SizedBox(width: isNarrow ? 0 : 16, height: isNarrow ? 16 : 0),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 24),
                          label: const Text("NEW ORDER (POS)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: () => context.go('/cashier/pos'),
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Cashier KPI cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final cross = w > 1000 ? 4 : (w > 600 ? 2 : 1);
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      children: [
                        SummaryCard(
                          label: "ACTIVE WORK QUEUE",
                          value: "${activeOrders.length} Orders",
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                        ),
                        SummaryCard(
                          label: "MY COMPLETED ORDERS",
                          value: "${todayCompleted.length} Handed Over",
                          icon: Icons.done_all,
                          color: Colors.green,
                        ),
                        SummaryCard(
                          label: "MY HANDOVER ORDERS",
                          value: "${todayHandover.length} Unpaid Orders",
                          icon: Icons.handshake_outlined,
                          color: Colors.deepPurple,
                        ),
                        SummaryCard(
                          label: "MY SHIFT SALES",
                          value: "Rs. ${todayRevenue.toStringAsFixed(2)}",
                          icon: Icons.monetization_on,
                          color: Colors.blue.shade700,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Recent sales logs
                const Text("My Recent Orders Placed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: recentOrders.isEmpty
                        ? const EmptyStateWidget(
                            title: "No Shifts Logs Yet",
                            message: "Click 'New Order' to start taking orders from customers.",
                            icon: Icons.shopping_basket_outlined,
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentOrders.length,
                            separatorBuilder: (context, idx) => const Divider(color: Colors.black12),
                            itemBuilder: (context, idx) {
                              final ord = recentOrders[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  child: Icon(
                                    ord.orderType == "dine-in"
                                        ? Icons.restaurant
                                        : (ord.orderType == "takeaway" ? Icons.shopping_bag : Icons.delivery_dining),
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text("Order #${ord.orderId} - ${ord.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  "Placed: ${DateFormat('dd/MM hh:mm a').format(ord.createdAt)} • Subtotal: Rs. ${ord.subtotal.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Rs. ${ord.grandTotal.toStringAsFixed(2)}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textColor),
                                    ),
                                    const SizedBox(width: 12),
                                    StatusBadge(status: ord.status),
                                  ],
                                ),
                                onTap: () => context.go('/cashier/receipt/${ord.id}'),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Global Bottom Nav for Cashier
Widget _buildBottomNav(BuildContext context, int activeIdx) {
  return BottomNavigationBar(
    currentIndex: activeIdx,
    selectedItemColor: AppTheme.primaryColor,
    unselectedItemColor: Colors.grey,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    onTap: (idx) {
      if (idx == 0) context.go('/cashier/dashboard');
      if (idx == 1) context.go('/cashier/pos');
      if (idx == 2) context.go('/cashier/orders');
      if (idx == 3) context.go('/cashier/orders/search');
      if (idx == 4) context.go('/cashier/reports');
    },
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
      BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "POS Menu"),
      BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "My Orders"),
      BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
      BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Reports"),
    ],
  );
}

// --- POS SCREEN (BROWSE MENU & CART) ---
class POSView extends ConsumerStatefulWidget {
  const POSView({super.key});

  @override
  ConsumerState<POSView> createState() => _POSViewState();
}

class _POSViewState extends ConsumerState<POSView> {
  String _selectedCatId = "All"; // All, Deals, or categoryId
  String _searchQuery = "";

  // Inline checkout panel state variables
  String _cartPanelMode = "cart"; // cart, customer, discount, summary, receipt
  String? _placedOrderDocId;

  // Checkout Step 1 controllers
  final _nameController = TextEditingController();
  final _tableController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _orderType = "dine-in";
  String _orderTaker = "Customer";
  final _customerFormKey = GlobalKey<FormState>();

  // Checkout Step 2 controller
  final _manualController = TextEditingController();
  final _discountFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = ref.read(cartProvider);
      if (cart.editingOrderDocId != null) {
        if (cart.editingOrderStatus == "Pending") {
          setState(() {
            _cartPanelMode = "cart";
          });
        } else if (cart.editingOrderStatus == "In Preparation" || cart.editingOrderStatus == "Ready") {
          _nameController.text = cart.customerName;
          _orderType = cart.orderType;
          _orderTaker = cart.orderTaker;
          _tableController.text = cart.tableNumber ?? '';
          _addressController.text = cart.deliveryAddress ?? '';
          _phoneController.text = cart.customerPhone ?? '';
          setState(() {
            _cartPanelMode = "customer";
          });
        } else if (cart.editingOrderStatus == "Handover") {
          if (cart.manualDiscount != 0.0) {
            _manualController.text = "-${cart.manualDiscount.abs().toString()}";
          } else {
            _manualController.text = "";
          }
          setState(() {
            _cartPanelMode = "discount";
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tableController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onProceedToCheckout() {
    final cart = ref.read(cartProvider);
    _nameController.text = cart.customerName;
    _orderType = cart.orderType;
    _orderTaker = cart.orderTaker;
    _tableController.text = cart.tableNumber ?? '';
    _addressController.text = cart.deliveryAddress ?? '';
    _phoneController.text = cart.customerPhone ?? '';
    setState(() {
      _cartPanelMode = "customer";
    });
  }

  void _onProceedToDiscounts() {
    if (_customerFormKey.currentState!.validate()) {
      ref.read(cartProvider.notifier).updateCustomerDetails(
        name: _nameController.text.trim().isEmpty ? "Walk-in Customer" : _nameController.text.trim(),
        type: _orderType,
        table: _orderType == "dine-in" ? _tableController.text.trim() : null,
        address: _orderType == "delivery" ? _addressController.text.trim() : null,
        phone: (_orderType == "delivery" || _orderType == "takeaway") ? _phoneController.text.trim() : null,
        orderTaker: _orderTaker,
      );

      final cart = ref.read(cartProvider);
      if (cart.manualDiscount != 0.0) {
        _manualController.text = "-${cart.manualDiscount.abs().toString()}";
      } else {
        _manualController.text = "";
      }

      setState(() {
        _cartPanelMode = "discount";
      });
    }
  }

  void _onProceedToSummary() {
    if (_discountFormKey.currentState!.validate()) {
      if (_manualController.text.isNotEmpty) {
        final val = double.tryParse(_manualController.text) ?? 0.0;
        ref.read(cartProvider.notifier).applyManualDiscount(val);
      } else {
        ref.read(cartProvider.notifier).applyManualDiscount(0.0);
      }
      setState(() {
        _cartPanelMode = "summary";
      });
    }
  }

  void _showError(String err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
    );
  }

  void _onAddItemPressed(MenuItemModel item) {
    final cart = ref.read(cartProvider);
    if (cart.editingOrderDocId != null &&
        (cart.editingOrderStatus == "In Preparation" ||
         cart.editingOrderStatus == "Ready" ||
         cart.editingOrderStatus == "Handover")) {
      _showError("Cannot edit menu items for In Preparation, Ready, or Handover orders.");
      return;
    }
    setState(() {
      _cartPanelMode = "cart";
    });

    if (item.variants.isEmpty) {
      ref.read(cartProvider.notifier).addItem(item);
    } else {
      showDialog<MenuItemVariant>(
        context: context,
        builder: (context) {
          MenuItemVariant? tempSelected = item.variants.first;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text("Select Variant for ${item.name}"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: item.variants.map((v) {
                    return RadioListTile<MenuItemVariant>(
                      title: Text(v.price != null && v.price! > 0 ? "${v.name} (Rs. ${v.price!.toStringAsFixed(0)})" : v.name),
                      value: v,
                      groupValue: tempSelected,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setDialogState(() {
                          tempSelected = val;
                        });
                      },
                    );
                  }).toList(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context, tempSelected);
                    },
                    child: const Text("Add to Cart"),
                  ),
                ],
              );
            },
          );
        },
      ).then((selected) {
        if (selected != null) {
          ref.read(cartProvider.notifier).addItem(item, variant: selected);
        }
      });
    }
  }

  void _showItemDetails(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: buildBase64Image(item.imageBase64),
              ),
            ),
            const SizedBox(height: 12),
            Text("Price: Rs. ${item.price.toStringAsFixed(2)}", style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Prep Time: ${item.prepTime} Minutes", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Text(item.description, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _onAddItemPressed(item);
            },
            child: const Text("Add to Cart"),
          )
        ],
      ),
    );
  }

  void _showSpecialInstructions(int index, CartItem item) {
    final controller = TextEditingController(text: item.specialInstructions);
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Special Instructions: ${item.item.name}",
        message: "e.g., No onions, Extra cheese, Less spicy, No ketchup, Extra sauce",
        inputLabel: "Instructions Note (max 200 chars)",
        inputPlaceholder: "Specify instructions...",
        inputController: controller,
        confirmLabel: "Save Notes",
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        final note = controller.text.trim();
        if (note.length <= 200) {
          ref.read(cartProvider.notifier).updateSpecialInstructions(index, note);
        } else {
          _showError("Instructions note exceeds 200 character limit.");
        }
      }
    });
  }

  void _onClearCart() {
    showDialog(
      context: context,
      builder: (context) => const ConfirmationDialog(
        title: "Clear Cart",
        message: "Are you sure you want to remove all items from the cart?",
        confirmLabel: "Clear Cart",
        isDanger: true,
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(cartProvider.notifier).clearCart();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final categories = ref.watch(categoriesStreamProvider).value ?? [];
    final activeCategories = categories.where((c) => c.status == "active").toList();

    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    final activeMenuItems = menuItems.where((i) => i.status == "active").toList();

    final deals = ref.watch(dealsStreamProvider).value ?? [];
    final activeDeals = deals.where((d) => d.status == "active").toList();

    final cart = ref.watch(cartProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMock = ref.watch(isMockModeProvider);

    // Filter menu items by search and category selection
    final filteredItems = activeMenuItems.where((item) {
      final matchesQuery = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCatId == "All" || item.categoryId == _selectedCatId;
      return matchesQuery && matchesCat;
    }).toList();

    // 1. LEFT PANEL: MENU BROWSER
    Widget menuPanel = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Filters
          SearchBarWidget(
            placeholder: "Search active menu food items...",
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // Categories horizontal list
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryTab(id: "All", name: "All Items"),
                _buildCategoryTab(id: "Deals", name: "Bundled Deals"),
                ...activeCategories.map((c) => _buildCategoryTab(id: c.id, name: c.name)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Menu items Grid or Deals list
          Expanded(
            child: _selectedCatId == "Deals"
                ? (activeDeals.isEmpty
                    ? const EmptyStateWidget(title: "No Deals Configured", message: "No active bundle deals available today.", icon: Icons.local_offer)
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: activeDeals.length,
                        itemBuilder: (context, idx) {
                          final d = activeDeals[idx];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: buildBase64Image(d.imageBase64)),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Rs. ${d.price.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              backgroundColor: AppTheme.primaryColor,
                                            ),
                                            onPressed: () {
                                              final cartState = ref.read(cartProvider);
                                              if (cartState.editingOrderDocId != null &&
                                                  (cartState.editingOrderStatus == "In Preparation" ||
                                                   cartState.editingOrderStatus == "Ready" ||
                                                   cartState.editingOrderStatus == "Handover")) {
                                                _showError("Cannot edit menu items for In Preparation, Ready, or Handover orders.");
                                                return;
                                              }
                                              setState(() {
                                                _cartPanelMode = "cart";
                                              });
                                              ref.read(cartProvider.notifier).addDeal(d);
                                            },
                                            child: const Text("Add", style: TextStyle(color: Colors.white, fontSize: 11)),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ))
                : (filteredItems.isEmpty
                    ? const EmptyStateWidget(title: "No Food Items Available", message: "Check filters or verify menu catalog is enabled.", icon: Icons.restaurant_menu)
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.80,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, idx) {
                          final item = filteredItems[idx];
                          return InkWell(
                            onTap: () => _onAddItemPressed(item),
                            onLongPress: () => _showItemDetails(item),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        buildBase64Image(item.imageBase64),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: IconButton(
                                            icon: const Icon(Icons.info, color: Colors.white70),
                                            onPressed: () => _showItemDetails(item),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  if (item.variants.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 2,
                                                      children: item.variants.map((v) {
                                                        final priceStr = v.price != null && v.price! > 0 ? " (Rs. ${v.price!.toStringAsFixed(0)})" : "";
                                                        return Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey.shade100,
                                                            borderRadius: BorderRadius.circular(3),
                                                            border: Border.all(color: Colors.grey.shade300),
                                                          ),
                                                          child: Text(
                                                            "${v.name}$priceStr",
                                                            style: TextStyle(color: Colors.grey.shade800, fontSize: 8, fontWeight: FontWeight.bold),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.price > 0 ? "Rs. ${item.price.toStringAsFixed(0)}" : "",
                                                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Text("${item.prepTime} min", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );

    final isEditingLocked = cart.editingOrderDocId != null &&
        (cart.editingOrderIsPaid ||
         cart.editingOrderStatus == "In Preparation" ||
         cart.editingOrderStatus == "Ready" ||
         cart.editingOrderStatus == "Handover");

    Widget cartPanel;
    if (_cartPanelMode == "customer") {
      cartPanel = _buildCustomerDetailsPanel(cart);
    } else if (_cartPanelMode == "discount") {
      cartPanel = _buildDiscountSelectorPanel(cart);
    } else if (_cartPanelMode == "summary") {
      cartPanel = _buildOrderSummaryPanel(cart);
    } else if (_cartPanelMode == "receipt") {
      cartPanel = _buildReceiptPrinterPanel(cart);
    } else {
      cartPanel = Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cart.editingOrderDocId != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Editing Order #${cart.editingOrderHumanId} (${cart.editingOrderStatus})",
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                        },
                        child: const Text("Cancel Edit", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text("My Cart", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          "${cart.items.length + cart.deals.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (!isEditingLocked && (cart.items.isNotEmpty || cart.deals.isNotEmpty))
                    TextButton(
                      onPressed: _onClearCart,
                      child: const Text("Clear Cart", style: TextStyle(color: Colors.red)),
                    )
                ],
              ),
              const Divider(),
              Expanded(
                child: cart.items.isEmpty && cart.deals.isEmpty
                    ? const Center(child: Text("Cart is empty.", style: TextStyle(color: Colors.grey)))
                    : ListView(
                        children: [
                          // Standalone Menu Items
                          ...cart.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final cartItem = entry.value;
                            final inst = cartItem.specialInstructions;
                            final variant = cartItem.selectedVariant;
                            final displayName = variant != null ? "${cartItem.item.name} (${variant.name})" : cartItem.item.name;
                            final displayPrice = variant?.price ?? cartItem.item.price;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: isEditingLocked ? null : () => _showSpecialInstructions(idx, cartItem),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text("Rs. ${displayPrice.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                              if (inst != null && inst.isNotEmpty)
                                                Text(
                                                  "Note: $inst",
                                                  style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontStyle: FontStyle.italic),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isEditingLocked) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(right: 12.0),
                                          child: Text(
                                            "Qty: ${cartItem.quantity}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                                              onPressed: () => ref.read(cartProvider.notifier).decreaseQuantity(idx),
                                            ),
                                            Text("${cartItem.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline, size: 20),
                                              onPressed: () => ref.read(cartProvider.notifier).increaseQuantity(idx),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                              onPressed: () => ref.read(cartProvider.notifier).removeItem(idx),
                                            ),
                                          ],
                                        ),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Deals
                          ...List.generate(cart.deals.length, (idx) {
                            final deal = cart.deals[idx];
                            final itemsDescription = getDealItemsDescription(deal.itemIds, menuItems);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(deal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Rs. ${deal.price.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11)),
                                  if (itemsDescription.isNotEmpty)
                                    Text(
                                      "Contains: $itemsDescription",
                                      style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                                    ),
                                ],
                              ),
                              trailing: isEditingLocked
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                      onPressed: () => ref.read(cartProvider.notifier).removeDeal(idx),
                                    ),
                            );
                          }),
                        ],
                      ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Subtotal:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("Rs. ${cart.itemsSubtotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
              CustomButton(
                text: "PROCEED TO CHECKOUT",
                onPressed: (cart.items.isNotEmpty || cart.deals.isNotEmpty)
                    ? _onProceedToCheckout
                    : null,
                icon: Icons.payment,
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: "Boss Food Corner POS",
        userName: user?.name ?? "Cashier",
        userRole: user?.role ?? "cashier",
        isMockMode: isMock,
        onLogout: () => ref.read(authActionProvider.notifier).logout(),
      ),
      bottomNavigationBar: _buildBottomNav(context, 1),
      body: isDesktop
          ? Row(
              children: [
                Expanded(flex: 7, child: menuPanel),
                Expanded(flex: 4, child: cartPanel),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: menuPanel),
                Expanded(flex: 2, child: cartPanel),
              ],
            ),
    );
  }

  Widget _buildCustomerDetailsPanel(CartState cart) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _customerFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Customer Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      if (cart.editingOrderDocId != null) {
                        ref.read(cartProvider.notifier).clearCart();
                      }
                      setState(() {
                        _cartPanelMode = "cart";
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      CustomTextField(
                        label: "Customer Name (Optional)",
                        placeholder: "e.g., John Doe",
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      ref.watch(waitersStreamProvider).when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Text(
                          "Failed to load waiters: $err",
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        data: (waiters) {
                          final activeWaiters = waiters.where((w) => w.status == 'active').toList();
                          final options = {"Customer", "Cashier", ...activeWaiters.map((w) => w.name)}.toList();
                          if (!options.contains(_orderTaker)) {
                            _orderTaker = "Customer";
                          }
                          return DropdownButtonFormField<String>(
                            value: _orderTaker,
                            decoration: const InputDecoration(
                              labelText: "Order Taker",
                              prefixIcon: Icon(Icons.badge_outlined),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: options.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text(opt));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _orderTaker = val ?? "Customer";
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _orderType,
                        decoration: const InputDecoration(
                          labelText: "Service Type",
                          prefixIcon: Icon(Icons.restaurant_menu),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: "dine-in", child: Text("Dine-In")),
                          DropdownMenuItem(value: "takeaway", child: Text("Takeaway")),
                          DropdownMenuItem(value: "delivery", child: Text("Delivery")),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _orderType = val ?? "dine-in";
                          });
                        },
                      ),
                      if (_orderType == "dine-in") ...[
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: "Table Number (Optional)",
                          placeholder: "e.g., Table 5",
                          controller: _tableController,
                          prefixIcon: Icons.table_restaurant,
                        ),
                      ],
                      if (_orderType == "takeaway") ...[
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: "Customer Phone (Optional)",
                          placeholder: "e.g., 03001234567",
                          controller: _phoneController,
                          prefixIcon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final clean = val.trim();
                              if (clean.length != 11 || !clean.startsWith("03") || double.tryParse(clean) == null) {
                                return "Enter a valid 11 digit number (03XXXXXXXXX)";
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                      if (_orderType == "delivery") ...[
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: "Customer Phone Number",
                          placeholder: "e.g., 03001234567",
                          controller: _phoneController,
                          prefixIcon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Phone number is required for deliveries";
                            final clean = val.trim();
                            if (clean.length != 11 || !clean.startsWith("03") || double.tryParse(clean) == null) {
                              return "Enter a valid 11 digit number (03XXXXXXXXX)";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: "Delivery Address",
                          placeholder: "Complete delivery address...",
                          controller: _addressController,
                          prefixIcon: Icons.location_on_outlined,
                          maxLines: 3,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Delivery address is required";
                            if (val.trim().length < 10) return "Provide a complete address (min 10 characters)";
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CustomButton(
                text: "NEXT: DISCOUNTS",
                onPressed: _onProceedToDiscounts,
                icon: Icons.navigate_next,
              ),
              const SizedBox(height: 8),
              CustomButton(
                text: "BACK",
                isOutlined: true,
                color: Colors.grey,
                onPressed: () => setState(() => _cartPanelMode = "cart"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountSelectorPanel(CartState cart) {
    final discountsState = ref.watch(discountsStreamProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _discountFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Discount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      if (cart.editingOrderDocId != null) {
                        ref.read(cartProvider.notifier).clearCart();
                      }
                      setState(() {
                        _cartPanelMode = "cart";
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Available Discounts", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      discountsState.when(
                        loading: () => const LinearProgressIndicator(color: AppTheme.primaryColor),
                        error: (err, _) => Text("Failed: $err", style: const TextStyle(color: Colors.red, fontSize: 12)),
                        data: (discounts) {
                          if (discounts.isEmpty) {
                            return const Text("No campaign discounts configured.", style: TextStyle(color: Colors.grey, fontSize: 12));
                          }
                          return Column(
                            children: discounts.map((d) {
                              final isSelected = cart.appliedManagerDiscount?.id == d.id;
                              final isPerc = d.type == "percentage";
                              return Card(
                                color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  dense: true,
                                  title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  trailing: Text(
                                    isPerc ? "${d.value.toStringAsFixed(0)}%" : "Rs. ${d.value.toStringAsFixed(0)}",
                                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  leading: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_off,
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
                                    size: 18,
                                  ),
                                  onTap: () {
                                    if (isSelected) {
                                      ref.read(cartProvider.notifier).removeManagerDiscount();
                                    } else {
                                      ref.read(cartProvider.notifier).applyManagerDiscount(d);
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      const Text("Add Manual Discount", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      CustomTextField(
                        label: "Manual Discount Amount (Negative Only)",
                        placeholder: "e.g., -50, -100",
                        controller: _manualController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final doubleVal = double.tryParse(val.trim());
                            if (doubleVal == null) return "Enter a valid number";
                            if (doubleVal > 0) return "Manual discount must be negative (e.g., -100)";
                            if (doubleVal.abs() > cart.itemsSubtotal) return "Discount cannot exceed subtotal";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Subtotal:"),
                  Text("Rs. ${cart.itemsSubtotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: "NEXT: SUMMARY",
                onPressed: _onProceedToSummary,
                icon: Icons.navigate_next,
              ),
              const SizedBox(height: 8),
              CustomButton(
                text: "BACK",
                isOutlined: true,
                color: Colors.grey,
                onPressed: () {
                  final isCustomerDetailsLocked = cart.editingOrderDocId != null && cart.editingOrderStatus == "Handover";
                  setState(() {
                    _cartPanelMode = isCustomerDetailsLocked ? "cart" : "customer";
                  });
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryPanel(CartState cart) {
    final settingsAsync = ref.watch(settingsStreamProvider);
    final cashierAct = ref.watch(cashierActionProvider);
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Order Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    if (cart.editingOrderDocId != null) {
                      ref.read(cartProvider.notifier).clearCart();
                    }
                    setState(() {
                      _cartPanelMode = "cart";
                    });
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Customer: ${cart.customerName.isEmpty ? 'Walk-in Customer' : cart.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text("Type: ${cart.orderType.toUpperCase()}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (cart.orderType == "dine-in" && cart.tableNumber != null)
                      Text("Table: ${cart.tableNumber}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (cart.orderType == "takeaway" && cart.customerPhone != null && cart.customerPhone!.isNotEmpty)
                      Text("Phone: ${cart.customerPhone}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (cart.orderType == "delivery") ...[
                      if (cart.customerPhone != null)
                        Text("Phone: ${cart.customerPhone}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (cart.deliveryAddress != null)
                        Text("Address: ${cart.deliveryAddress}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    const Divider(height: 20),

                    // Items breakdown list
                    ...cart.items.map((i) {
                      final dispName = i.selectedVariant != null ? "${i.item.name} (${i.selectedVariant!.name})" : i.item.name;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("${i.quantity}x $dispName", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            Text("Rs. ${i.totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                    ...cart.deals.map((d) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("1x Deal: ${d.name}", style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor), overflow: TextOverflow.ellipsis)),
                            Text("Rs. ${d.price.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 12),
            settingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text("Settings load error: $err", style: const TextStyle(color: Colors.red)),
              data: (settings) {
                double subtotal = cart.itemsSubtotal;
                double managerD = 0.0;
                if (cart.appliedManagerDiscount != null) {
                  if (cart.appliedManagerDiscount!.type == "percentage") {
                    managerD = subtotal * (cart.appliedManagerDiscount!.value / 100);
                  } else {
                    managerD = cart.appliedManagerDiscount!.value;
                  }
                }
                double manualD = cart.manualDiscount.abs();
                double discountAmount = managerD + manualD;
                double baseForTax = subtotal - discountAmount;
                if (baseForTax < 0) baseForTax = 0;
                
                double tax = baseForTax * (settings.taxRate / 100);
                double delivery = cart.orderType == "delivery" ? settings.deliveryCharges : 0.0;
                double grandTotal = baseForTax + tax + delivery;

                return Column(
                  children: [
                    _buildSummaryRow("Subtotal", "Rs. ${subtotal.toStringAsFixed(2)}"),
                    if (discountAmount > 0)
                      _buildSummaryRow("Discounts", "- Rs. ${discountAmount.toStringAsFixed(2)}", isDiscount: true),
                    if (tax > 0)
                      _buildSummaryRow("Taxes (${settings.taxRate}%)", "Rs. ${tax.toStringAsFixed(2)}"),
                    if (delivery > 0)
                      _buildSummaryRow("Delivery Charges", "Rs. ${delivery.toStringAsFixed(2)}"),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (cashierAct.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      CustomButton(
                        text: cart.editingOrderDocId != null ? "SAVE CHANGES" : "CONFIRM & SUBMIT ORDER",
                        icon: Icons.check_circle_outline,
                        onPressed: () async {
                          ref.read(cartProvider.notifier).updatePaymentDetails(grandTotal);
                          try {
                            await ref.read(cashierActionProvider.notifier).submitOrder(settings);
                            final submitState = ref.read(cashierActionProvider);
                            if (submitState.hasError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(submitState.error.toString()), backgroundColor: Colors.red),
                              );
                            } else {
                              final orderId = submitState.value;
                              if (orderId != null && orderId.isNotEmpty) {
                                setState(() {
                                  _placedOrderDocId = orderId;
                                  _cartPanelMode = "receipt";
                                });
                              }
                            }
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
            const SizedBox(height: 8),
            CustomButton(
              text: "BACK",
              isOutlined: true,
              color: Colors.grey,
              onPressed: () => setState(() => _cartPanelMode = "discount"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 12, color: isDiscount ? Colors.green : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildReceiptPrinterPanel(CartState cart) {
    final allOrders = ref.watch(allOrdersStreamProvider).value ?? [];
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    OrderModel? order;
    if (_placedOrderDocId != null) {
      try {
        order = allOrders.firstWhere((o) => o.id == _placedOrderDocId);
      } catch (_) {}
    }

    if (order == null) {
      return Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text("Saving order details...", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              CustomButton(
                text: "Back to Cart",
                onPressed: () => setState(() {
                  _cartPanelMode = "cart";
                  _placedOrderDocId = null;
                }),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Order Saved Successfully!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 4,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    child: ReceiptPreviewWidget(order: order),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: "Print Receipt",
              icon: Icons.print,
              onPressed: () => triggerWebPrint(context, order!),
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: "Done / New Order",
              icon: Icons.done_all,
              isOutlined: true,
              onPressed: () {
                setState(() {
                  _cartPanelMode = "cart";
                  _placedOrderDocId = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab({required String id, required String name}) {
    final isSelected = _selectedCatId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(name),
        selected: isSelected,
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedCatId = id;
            });
          }
        },
      ),
    );
  }
}

// --- RECEIPT PRINT SCREEN ---
class ReceiptView extends ConsumerWidget {
  final String orderId;

  const ReceiptView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(cashierOrdersStreamProvider).value ?? [];
    OrderModel? order;
    try {
      order = orders.firstWhere((o) => o.id == orderId);
    } catch (_) {}

    // Fallback: check all orders
    if (order == null) {
      final all = ref.watch(allOrdersStreamProvider).value ?? [];
      try {
        order = all.firstWhere((o) => o.id == orderId);
      } catch (_) {}
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Receipt Loading")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Receipt Placed - #${order.orderId}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/cashier/dashboard');
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thermal Paper visual representation
                Card(
                  elevation: 6,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  child: ReceiptPreviewWidget(order: order),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: "Print",
                        icon: Icons.print,
                        onPressed: () => triggerWebPrint(context, order!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: "New Order",
                        icon: Icons.add_shopping_cart,
                        isOutlined: true,
                        onPressed: () => context.go('/cashier/pos'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- ORDER TRACKING VIEW ---
class OrderTrackingView extends ConsumerWidget {
  const OrderTrackingView({super.key});

  void _showError(BuildContext context, String err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
    );
  }

  void _onCancelOrder(BuildContext context, WidgetRef ref, OrderModel order, String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Cancel Order #${order.orderId}",
        message: "Are you sure you want to cancel this order? This action can only be performed if status is Pending.",
        inputLabel: "Reason for Cancellation",
        inputPlaceholder: "Customer changed mind...",
        inputController: reasonController,
        confirmLabel: "Cancel Order",
        isDanger: true,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).cancelOrder(order.id, reasonController.text, userId);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(context, actState.error.toString());
          }
        } catch (e) {
          _showError(context, e.toString());
        }
      }
    });
  }

  void _onCompleteOrder(BuildContext context, WidgetRef ref, OrderModel order, String userId) {
    final proceedHandover = () async {
      String? assignedRider;
      if (order.orderType.toLowerCase() == "delivery") {
        assignedRider = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const SelectRiderDialog(),
        );
        if (assignedRider == null) {
          return; // Cancelled rider selection
        }
        await ref.read(orderRepositoryProvider).updateOrderRider(order.id, assignedRider);
      }

      if (order.isPaid) {
        await ref.read(orderRepositoryProvider).updateOrderStatus(order.id, "Completed", userId, "cashier");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Order completed and handed over!"), backgroundColor: Colors.green),
          );
        }
      } else {
        if (!context.mounted) return;
        final result = await showDialog<String>(
          context: context,
          builder: (context) => HandoverPaymentDialog(order: order),
        );
        if (result != null) {
          final status = result == "paid" ? "Completed" : "Handover";
          if (result == "paid") {
            await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(order.id, true, userId);
          }
          await ref.read(orderRepositoryProvider).updateOrderStatus(order.id, status, userId, "cashier");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result == "paid"
                    ? "Order completed and marked as PAID successfully!"
                    : "Order marked as UNPAID HANDOVER successfully!"),
                backgroundColor: result == "paid" ? Colors.green : Colors.orange,
              ),
            );
          }
        }
      }
    };

    proceedHandover().catchError((e) {
      if (context.mounted) {
        _showError(context, e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(cashierOrdersStreamProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text("My Shifts Work Queue")),
      bottomNavigationBar: _buildBottomNav(context, 2),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Loading orders queue..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          // Display only today's active orders
          final activeOrders = orders.where((o) => o.status != "Completed" && o.status != "Cancelled").toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: activeOrders.isEmpty
                ? const EmptyStateWidget(
                    title: "Active queue is clear!",
                    message: "All orders placed are fully processed or prepared.",
                    icon: Icons.list_alt,
                  )
                : ListView.builder(
                    itemCount: activeOrders.length,
                    itemBuilder: (context, idx) {
                      final ord = activeOrders[idx];
                      final isPending = ord.status == "Pending";
                      final isReady = ord.status == "Ready";
                      final isHandover = ord.status == "Handover";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Order #${ord.orderId} [Token: ${ord.tokenId ?? '000'}] - ${ord.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Type: ${ord.orderType.toUpperCase()} • Grand Total: Rs. ${ord.grandTotal.toStringAsFixed(0)}",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  StatusBadge(status: ord.status),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => context.push('/cashier/receipt/${ord.id}'),
                                    child: const Text("View Receipt"),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!ord.isPaid) ...[
                                    TextButton.icon(
                                      onPressed: () {
                                        final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
                                        ref.read(cartProvider.notifier).startEditing(ord, menuItems);
                                        context.go('/cashier/pos');
                                      },
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text("Edit Order"),
                                    ),
                                  ],
                                  if (isPending) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => _onCancelOrder(context, ref, ord, user?.uid ?? ''),
                                      child: const Text("Cancel Order"),
                                    ),
                                  ],
                                  if (!ord.isPaid) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () async {
                                        try {
                                          await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(ord.id, true, user?.uid ?? '');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Order marked as PAID!"), backgroundColor: Colors.green),
                                          );
                                        } catch (e) {
                                          _showError(context, e.toString());
                                        }
                                      },
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text("Pay Bill"),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.all(Radius.circular(4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text("PAID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (isReady) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                      onPressed: () => _onCompleteOrder(context, ref, ord, user?.uid ?? ''),
                                      child: const Text("Hand Over Food"),
                                    ),
                                  ],
                                  if (isHandover) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () async {
                                        try {
                                          if (!ord.isPaid) {
                                            await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(ord.id, true, user?.uid ?? '');
                                          }
                                          await ref.read(orderRepositoryProvider).updateOrderStatus(ord.id, "Completed", user?.uid ?? '', "cashier");
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Order completed successfully!"), backgroundColor: Colors.green),
                                          );
                                        } catch (e) {
                                          _showError(context, e.toString());
                                        }
                                      },
                                      child: Text(ord.isPaid ? "Complete Order" : "Mark Paid & Complete"),
                                    ),
                                  ]
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

// --- ORDER SEARCH SCREEN ---
class OrderSearchView extends ConsumerStatefulWidget {
  const OrderSearchView({super.key});

  @override
  ConsumerState<OrderSearchView> createState() => _OrderSearchViewState();
}

class _OrderSearchViewState extends ConsumerState<OrderSearchView> {
  String _searchQuery = "";
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(cashierOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Search Order Logs")),
      bottomNavigationBar: _buildBottomNav(context, 3),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Loading database indexing..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          // Perform filtering
          final filtered = orders.where((o) {
            final query = _searchQuery.trim().toLowerCase();
            bool matchesQuery = true;
            if (query.isNotEmpty) {
              if (query.length == 6 && double.tryParse(query) != null) {
                matchesQuery = o.orderId == query; // exact 6 digits
              } else {
                matchesQuery = o.customerName.toLowerCase().contains(query);
              }
            }

            bool matchesDate = true;
            if (_filterDate != null) {
              matchesDate = _isSameDay(o.createdAt, _filterDate!);
            }

            return matchesQuery && matchesDate;
          }).toList();

          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        return Flex(
                          direction: isNarrow ? Axis.vertical : Axis.horizontal,
                          crossAxisAlignment: isNarrow ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                          children: [
                            if (isNarrow) ...[
                              SearchBarWidget(
                                placeholder: "Search exact 6-digit Order ID or partial Customer Name...",
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(_filterDate == null ? "Select Date" : DateFormat.yMMMd().format(_filterDate!)),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _filterDate ?? DateTime.now(),
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime.now(),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _filterDate = picked;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  if (_filterDate != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _filterDate = null;
                                        });
                                      },
                                    )
                                  ]
                                ],
                              ),
                            ] else ...[
                              Expanded(
                                flex: 3,
                                child: SearchBarWidget(
                                  placeholder: "Search exact 6-digit Order ID or partial Customer Name...",
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                                icon: const Icon(Icons.calendar_today),
                                label: Text(_filterDate == null ? "Select Date" : DateFormat.yMMMd().format(_filterDate!)),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _filterDate ?? DateTime.now(),
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _filterDate = picked;
                                    });
                                  }
                                },
                              ),
                              if (_filterDate != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _filterDate = null;
                                    });
                                  },
                                )
                              ]
                            ]
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: filtered.isEmpty
                          ? const EmptyStateWidget(
                              title: "No Matching Orders",
                              message: "Modify search terms or check selected date filters.",
                              icon: Icons.search_off_outlined,
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, idx) => const Divider(color: Colors.black12),
                              itemBuilder: (context, idx) {
                                final ord = filtered[idx];
                                return ListTile(
                                  title: Text("Order #${ord.orderId} - ${ord.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    "Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(ord.createdAt)} • Type: ${ord.orderType.toUpperCase()}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Rs. ${ord.grandTotal.toStringAsFixed(2)}",
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 12),
                                      StatusBadge(status: ord.status),
                                    ],
                                  ),
                                  onTap: () => context.push('/cashier/receipt/${ord.id}'),
                                );
                              },
                            ),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- CASHIER REPORTS SCREEN ---
class CashierReportsView extends ConsumerStatefulWidget {
  const CashierReportsView({super.key});

  @override
  ConsumerState<CashierReportsView> createState() => _CashierReportsViewState();
}

class _CashierReportsViewState extends ConsumerState<CashierReportsView> {
  DateTime _filterDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(cashierOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("My Sales Analytics")),
      bottomNavigationBar: _buildBottomNav(context, 4),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Compiling shift sales logs..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          // Filter to select date only
          final completed = orders.where((o) => _isSameDay(o.createdAt, _filterDate) && o.status == "Completed").toList();

          final double revenue = completed.fold(0.0, (sum, o) => sum + o.grandTotal);
          final double discounts = completed.fold(0.0, (sum, o) => sum + o.discountAmount);
          final double tax = completed.fold(0.0, (sum, o) => sum + o.tax);
          final double delivery = completed.fold(0.0, (sum, o) => sum + o.deliveryCharges);
          final double avgValue = completed.isNotEmpty ? revenue / completed.length : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Shift Sales Performance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text("Day: ${DateFormat.yMMMMd().format(_filterDate)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                      icon: const Icon(Icons.date_range),
                      label: const Text("Change Date"),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _filterDate = picked;
                          });
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 20),

                // KPI grid cards
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        label: "NET SHIFT REVENUE",
                        value: "Rs. ${revenue.toStringAsFixed(2)}",
                        icon: Icons.payments,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        label: "SHIFTS COMPLETED",
                        value: "${completed.length} Orders",
                        icon: Icons.shopping_bag,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (completed.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: Text(
                        "No sales records logged by you on this date.",
                        style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  // Simple shift itemized sold checklist breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Food items sold by me today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(height: 24),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: completed.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, idx) {
                              final o = completed[idx];
                              final timeStr = DateFormat('hh:mm a').format(o.createdAt);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Order #${o.orderId} - ${o.customerName} (${o.orderType.toUpperCase()})",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                        ),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...o.items.map((i) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("${i.quantity}x ${i.name}", style: const TextStyle(fontSize: 12)),
                                          Text("Rs. ${i.totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )),
                                    ...o.deals.map((d) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("1x Bundle: ${d['name']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                          Text("Rs. ${double.tryParse(d['price'].toString())?.toStringAsFixed(0) ?? d['price']}", style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Order Total", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text("Rs. ${o.grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  final local = a.toLocal();
  // Orders before 5 AM belong to the previous business day
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);
  final sel = DateTime(b.year, b.month, b.day);
  return logicalDate == sel;
}

class HandoverPaymentDialog extends StatelessWidget {
  final OrderModel order;

  const HandoverPaymentDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Confirm Handover Payment", style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text(
        "Please specify the payment status for this order handover. "
        "Clicking 'UNPAID' hands over the order but flags it as Unpaid (Handover status).",
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, "unpaid"),
          child: const Text("UNPAID HANDOVER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, "paid"),
          child: const Text("COLLECT Rs. & COMPLETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class SelectRiderDialog extends ConsumerWidget {
  const SelectRiderDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridersState = ref.watch(ridersStreamProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Assign Rider for Delivery", style: TextStyle(fontWeight: FontWeight.bold)),
      content: ridersState.when(
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Text("Error loading riders: $err", style: const TextStyle(color: Colors.red)),
        data: (riders) {
          final activeRiders = riders.where((r) => r.status == 'active').toList();
          if (activeRiders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                "No active riders configured. Please add an active rider from the manager panel first.",
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          return SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: activeRiders.length,
              itemBuilder: (context, idx) {
                final rider = activeRiders[idx];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
                  title: Text(rider.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(rider.phone),
                  onTap: () => Navigator.pop(context, rider.name),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
