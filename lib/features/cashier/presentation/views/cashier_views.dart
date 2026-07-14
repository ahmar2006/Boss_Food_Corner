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
                    final cross = w > 900 ? 3 : (w > 600 ? 3 : 1);
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: w > 900 ? 3.0 : 2.2,
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
                                  "Placed: ${DateFormat('dd/MM hh:mm a').format(ord.createdAt)} • Total: Rs. ${ord.grandTotal.toStringAsFixed(2)}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: StatusBadge(status: ord.status),
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
  bool _mobileShowCart = false;

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
            _manualController.text = cart.manualDiscount.abs().toString();
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
        _manualController.text = cart.manualDiscount.abs().toString();
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

  void _showAddManualItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Custom Cart Item", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: "Item Name",
                placeholder: "e.g., Cold Drink Extra, Special Dessert",
                controller: nameController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Item name is required";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: "Price (Rs.)",
                placeholder: "e.g., 150.00",
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Price is required";
                  final price = double.tryParse(val.trim());
                  if (price == null || price < 0) return "Enter a valid positive price";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final price = double.parse(priceController.text.trim());
                ref.read(cartProvider.notifier).addManualItem(name, price);
                Navigator.pop(context);
              }
            },
            child: const Text("ADD TO CART", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  void _showCartSpecialInstructions() {
    final cart = ref.read(cartProvider);
    final controller = TextEditingController(text: cart.specialInstructions);
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Order Special Instructions",
        message: "Specify instructions for the entire order (e.g., Send extra tissues, Pack separately, etc.)",
        inputLabel: "Order Note (max 200 chars)",
        inputPlaceholder: "Specify order notes...",
        inputController: controller,
        confirmLabel: "Save Instructions",
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        final note = controller.text.trim();
        if (note.length <= 200) {
          ref.read(cartProvider.notifier).updateCartSpecialInstructions(note);
        } else {
          _showError("Order instructions note exceeds 200 character limit.");
        }
      }
    });
  }

  void _showDealSpecialInstructions(int index, CartDeal cartDeal) {
    final controller = TextEditingController(text: cartDeal.specialInstructions);
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Special Instructions: ${cartDeal.deal.name}",
        message: "Specify instructions for this bundle (e.g., Spicy wings, Pepsi instead of Coke, etc.)",
        inputLabel: "Instructions Note (max 200 chars)",
        inputPlaceholder: "Specify instructions...",
        inputController: controller,
        confirmLabel: "Save Notes",
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        final note = controller.text.trim();
        if (note.length <= 200) {
          ref.read(cartProvider.notifier).updateDealSpecialInstructions(index, note);
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
    final List<dynamic> filteredItems = [];
    if (_selectedCatId == "All") {
      filteredItems.addAll(activeMenuItems.where((item) {
        return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }));
      filteredItems.addAll(activeDeals.where((deal) {
        return deal.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }));
    } else {
      filteredItems.addAll(activeMenuItems.where((item) {
        final matchesQuery = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCat = item.categoryId == _selectedCatId;
        return matchesQuery && matchesCat;
      }));
    }

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
                            if (item is DealModel) {
                              return InkWell(
                                onTap: () {
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
                                  ref.read(cartProvider.notifier).addDeal(item);
                                },
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
                                              left: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  "DEAL",
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "Rs. ${item.price.toStringAsFixed(0)}",
                                                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  const Icon(Icons.local_offer, color: Colors.amber, size: 16),
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
                            } else {
                              final MenuItemModel menuItem = item as MenuItemModel;
                              return InkWell(
                                onTap: () => _onAddItemPressed(menuItem),
                                onLongPress: () => _showItemDetails(menuItem),
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
                                            buildBase64Image(menuItem.imageBase64),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: IconButton(
                                                icon: const Icon(Icons.info, color: Colors.white70),
                                                onPressed: () => _showItemDetails(menuItem),
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
                                                      Text(menuItem.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      if (menuItem.variants.isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Wrap(
                                                          spacing: 4,
                                                          runSpacing: 2,
                                                          children: menuItem.variants.map((v) {
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
                                                    menuItem.price > 0 ? "Rs. ${menuItem.price.toStringAsFixed(0)}" : "",
                                                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  Text("${menuItem.prepTime} min", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
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
                            }
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!isEditingLocked)
                        TextButton.icon(
                          onPressed: () => _showAddManualItemDialog(context),
                          icon: const Icon(Icons.add, size: 16, color: Colors.green),
                          label: const Text("Custom Item", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (!isEditingLocked && (cart.items.isNotEmpty || cart.deals.isNotEmpty))
                        TextButton(
                          onPressed: _onClearCart,
                          child: const Text("Clear Cart", style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
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
                            final cartDeal = cart.deals[idx];
                            final dealModel = cartDeal.deal;
                            final inst = cartDeal.specialInstructions;
                            final itemsDescription = getDealItemsDescription(dealModel.itemIds, menuItems);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: isEditingLocked ? null : () => _showDealSpecialInstructions(idx, cartDeal),
                              title: Text(dealModel.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Rs. ${dealModel.price.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11)),
                                  if (itemsDescription.isNotEmpty)
                                    Text(
                                      "Contains: $itemsDescription",
                                      style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                                    ),
                                  if (inst != null && inst.isNotEmpty)
                                    Text(
                                      "Note: $inst",
                                      style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
              if (cart.items.isNotEmpty || cart.deals.isNotEmpty) ...[
                if (!isEditingLocked)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Cart Notes (Entire Order)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(
                      cart.specialInstructions?.isNotEmpty == true
                          ? cart.specialInstructions!
                          : "Tap edit icon to add notes for the whole order...",
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: cart.specialInstructions?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                        color: cart.specialInstructions?.isNotEmpty == true ? Colors.amber.shade900 : Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        cart.specialInstructions?.isNotEmpty == true ? Icons.edit_note : Icons.add_comment_outlined,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      onPressed: _showCartSpecialInstructions,
                    ),
                  )
                else if (cart.specialInstructions?.isNotEmpty == true)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Cart Notes (Entire Order)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(
                      cart.specialInstructions!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
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
      body: Column(
        children: [
          if (!isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("1. BROWSE MENU")),
                      selected: !_mobileShowCart,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !_mobileShowCart ? AppTheme.primaryColor : Colors.grey,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _mobileShowCart = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          "2. MY CART (${cart.items.length + cart.deals.length})"
                        ),
                      ),
                      selected: _mobileShowCart,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _mobileShowCart ? AppTheme.primaryColor : Colors.grey,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _mobileShowCart = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(flex: 7, child: menuPanel),
                      Expanded(flex: 4, child: cartPanel),
                    ],
                  )
                : (_mobileShowCart ? cartPanel : menuPanel),
          ),
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
                        label: "Manual Discount Amount",
                        placeholder: "e.g., 50, 100",
                        controller: _manualController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final doubleVal = double.tryParse(val.trim());
                            if (doubleVal == null) return "Enter a valid number";
                            if (doubleVal < 0) return "Enter discount without a negative sign";
                            if (doubleVal > cart.itemsSubtotal) return "Discount cannot exceed subtotal";
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
                            Expanded(child: Text("1x Deal: ${d.deal.name}", style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor), overflow: TextOverflow.ellipsis)),
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
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    final orderAsync = _placedOrderDocId != null
        ? ref.watch(singleOrderProvider(_placedOrderDocId!))
        : const AsyncValue<OrderModel?>.data(null);
    final OrderModel? order = orderAsync.value;

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
    final orderAsync = ref.watch(singleOrderProvider(orderId));
    final OrderModel? order = orderAsync.value;

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
class OrderTrackingView extends ConsumerStatefulWidget {
  const OrderTrackingView({super.key});

  @override
  ConsumerState<OrderTrackingView> createState() => _OrderTrackingViewState();
}

class _OrderTrackingViewState extends ConsumerState<OrderTrackingView> {
  String _searchQuery = "";
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showError(BuildContext context, String err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
    );
  }

  void _onCancelOrder(BuildContext context, OrderModel order, String userId) {
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
          ref.invalidate(cashierOrdersStreamProvider);
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

  void _onCompleteOrder(BuildContext context, OrderModel order, String userId) {
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
        ref.invalidate(cashierOrdersStreamProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Order completed and handed over!"), backgroundColor: Colors.green),
          );
        }
      } else {
        if (!context.mounted) return;
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => HandoverPaymentDialog(order: order),
        );
        if (result != null) {
          final isPaid = result['status'] == "paid";
          final status = isPaid ? "Completed" : "Handover";
          await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(
            order.id,
            isPaid,
            userId,
            amountReceived: result['cashReceived'],
            change: result['change'],
          );
          await ref.read(orderRepositoryProvider).updateOrderStatus(order.id, status, userId, "cashier");
          ref.invalidate(cashierOrdersStreamProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isPaid
                    ? "Order completed and marked as PAID successfully!"
                    : "Order marked as UNPAID HANDOVER successfully!"),
                backgroundColor: isPaid ? Colors.green : Colors.orange,
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
  Widget build(BuildContext context) {
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
          final filteredOrders = _searchQuery.isEmpty
              ? activeOrders
              : activeOrders.where((o) => (o.tokenId ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search active orders by Token ID...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredOrders.isEmpty
                      ? const EmptyStateWidget(
                          title: "No matching orders found",
                          message: "Try searching by another Token ID.",
                          icon: Icons.search_off,
                        )
                      : ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, idx) {
                            final ord = filteredOrders[idx];
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
                                  Expanded(
                                    child: Column(
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
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: ord.status),
                                ],
                              ),
                              const Divider(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => context.push('/cashier/receipt/${ord.id}'),
                                    child: const Text("View Receipt"),
                                  ),
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
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => _onCancelOrder(context, ord, user?.uid ?? ''),
                                      child: const Text("Cancel Order"),
                                    ),
                                  ],
                                  if (!ord.isPaid) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () async {
                                        final result = await showDialog<Map<String, dynamic>>(
                                          context: context,
                                          builder: (context) => PayBillDialog(order: ord),
                                        );
                                        if (result != null) {
                                          try {
                                            await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(
                                              ord.id,
                                              true,
                                              user?.uid ?? '',
                                              amountReceived: result['cashReceived'],
                                              change: result['change'],
                                            );
                                            ref.invalidate(cashierOrdersStreamProvider);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Order marked as PAID!"), backgroundColor: Colors.green),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              _showError(context, e.toString());
                                            }
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text("Pay Bill"),
                                    ),
                                  ] else ...[
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
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                    onPressed: () => _onCompleteOrder(context, ord, user?.uid ?? ''),
                                      child: const Text("Hand Over Food"),
                                    ),
                                  ],
                                  if (isHandover) ...[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () async {
                                        try {
                                          double? cashReceived;
                                          double? changeAmount;
                                          if (!ord.isPaid) {
                                            final result = await showDialog<Map<String, dynamic>>(
                                              context: context,
                                              builder: (context) => PayBillDialog(order: ord),
                                            );
                                            if (result == null) return;
                                            cashReceived = result['cashReceived'];
                                            changeAmount = result['change'];
                                            await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(
                                              ord.id,
                                              true,
                                              user?.uid ?? '',
                                              amountReceived: cashReceived,
                                              change: changeAmount,
                                            );
                                          }
                                          await ref.read(orderRepositoryProvider).updateOrderStatus(ord.id, "Completed", user?.uid ?? '', "cashier");
                                          ref.invalidate(cashierOrdersStreamProvider);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Order completed successfully!"), backgroundColor: Colors.green),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            _showError(context, e.toString());
                                          }
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
                ),
              ],
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
              final cleanQuery = query.replaceAll(RegExp(r'^0+'), '');
              final cleanOrderId = o.orderId.replaceAll(RegExp(r'^0+'), '');
              final cleanTokenId = (o.tokenId ?? '').replaceAll(RegExp(r'^0+'), '');
              if (cleanQuery.isNotEmpty && int.tryParse(cleanQuery) != null) {
                matchesQuery = (cleanOrderId == cleanQuery || cleanTokenId == cleanQuery);
              } else {
                matchesQuery = o.customerName.toLowerCase().contains(query) ||
                    o.orderId.contains(query) ||
                    (o.tokenId ?? '').contains(query);
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
                                    "Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(ord.createdAt)} • Total: Rs. ${ord.grandTotal.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: StatusBadge(status: ord.status),
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
  bool _isUnlocked = false;
  final _passController = TextEditingController();

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStreamProvider);
    final ordersState = ref.watch(cashierOrdersStreamProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("Error: $e"))),
      data: (settings) {
        final hasPassword = settings.cashierReportPassword.isNotEmpty;
        if (hasPassword && !_isUnlocked) {
          return Scaffold(
            appBar: AppBar(title: const Text("Access Locked")),
            bottomNavigationBar: _buildBottomNav(context, 4),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock, size: 64, color: AppTheme.primaryColor),
                          const SizedBox(height: 16),
                          const Text(
                            "Enter Report Password",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "This area is password protected. Enter the password set by your manager to view sales reports.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _passController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Password",
                              prefixIcon: Icon(Icons.password),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          CustomButton(
                            text: "UNLOCK REPORTS",
                            onPressed: () {
                              if (_passController.text.trim() == settings.cashierReportPassword) {
                                setState(() {
                                  _isUnlocked = true;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Incorrect password!"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Shift Sales Performance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text("Day: ${DateFormat.yMMMMd().format(_filterDate)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
                const SizedBox(height: 16),
                StreamBuilder<DailyClosingModel?>(
                  stream: ref.read(orderRepositoryProvider).watchDailyClosing(DateFormat('yyyy-MM-dd').format(_filterDate)),
                  builder: (context, snapshot) {
                    final closing = snapshot.data;
                    final user = ref.read(authStateProvider).value;

                    // Compute current aggregates
                    final dayOrders = orders.where((o) => _isSameDay(o.createdAt, _filterDate)).toList();
                    final nonCancelled = dayOrders.where((o) => o.status != "Cancelled").toList();
                    final cancelled = dayOrders.where((o) => o.status == "Cancelled").toList();

                    final isClosed = closing != null && !closing.isReleased;

                    return Card(
                      color: isClosed ? Colors.green.shade50 : Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isClosed ? "Daily Closing Submitted" : "Daily Closing Pending",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isClosed ? Colors.green.shade900 : Colors.blue.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClosed ? Colors.green : AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(isClosed ? Icons.visibility : Icons.check_circle),
                              label: Text(isClosed ? "VIEW CLOSING" : "ADD DAILY CLOSING"),
                              onPressed: () async {
                                if (isClosed) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ViewDailyClosingDialog(
                                      closing: closing,
                                      onPrint: () => triggerClosingPrint(context, closing),
                                    ),
                                  );
                                } else {
                                  final result = await showDialog<Map<String, double>>(
                                    context: context,
                                    builder: (context) => AddDailyClosingDialog(
                                      totalPunchOrders: nonCancelled.length,
                                      cancelledOrders: cancelled.length,
                                    ),
                                  );
                                  if (result != null) {
                                    final dateStr = DateFormat('yyyy-MM-dd').format(_filterDate);
                                    final newClosing = DailyClosingModel(
                                      id: dateStr,
                                      cashAmount: result['cash']!,
                                      onlineAmount: result['online']!,
                                      cardAmount: result['card']!,
                                      totalPunchOrders: nonCancelled.length,
                                      cancelledOrders: cancelled.length,
                                      totalConfirmedOrders: completed.length,
                                      totalTodayRevenue: revenue,
                                      closedBy: user?.uid ?? '',
                                      closedByName: user?.name ?? 'Cashier',
                                      createdAt: DateTime.now(),
                                      isReleased: false,
                                    );
                                    try {
                                      await ref.read(orderRepositoryProvider).saveDailyClosing(newClosing);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Daily closing saved successfully!"), backgroundColor: Colors.green),
                                        );
                                        triggerClosingPrint(context, newClosing);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Failed to save closing: $e"), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // KPI grid cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    if (isNarrow) {
                      return Column(
                        children: [
                          SummaryCard(
                            label: "NET SHIFT REVENUE",
                            value: "Rs. ${revenue.toStringAsFixed(2)}",
                            icon: Icons.payments,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          SummaryCard(
                            label: "SHIFTS COMPLETED",
                            value: "${completed.length} Orders",
                            icon: Icons.shopping_bag,
                            color: Colors.blue,
                          ),
                        ],
                      );
                    }
                    return Row(
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
                    );
                  }
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
                                        Expanded(
                                          child: Text(
                                            "Order #${o.orderId} - ${o.customerName} (${o.orderType.toUpperCase()})",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                                          Expanded(
                                            child: Text(
                                              "${i.quantity}x ${i.name}",
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text("Rs. ${i.totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )),
                                    ...o.deals.map((d) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "1x Bundle: ${d['name']}",
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
      },
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

class HandoverPaymentDialog extends StatefulWidget {
  final OrderModel order;

  const HandoverPaymentDialog({super.key, required this.order});

  @override
  State<HandoverPaymentDialog> createState() => _HandoverPaymentDialogState();
}

class _HandoverPaymentDialogState extends State<HandoverPaymentDialog> {
  String _paymentMode = "unpaid"; // unpaid or paid
  final _cashController = TextEditingController();
  double _cashReceived = 0.0;
  double _change = 0.0;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _cashController.removeListener(_calculateChange);
    _cashController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final val = _cashController.text.trim();
    if (val.isEmpty) {
      setState(() {
        _cashReceived = 0.0;
        _change = 0.0;
        _errorMsg = null;
      });
      return;
    }
    final entered = double.tryParse(val);
    if (entered == null) {
      setState(() {
        _errorMsg = "Please enter a valid number";
      });
      return;
    }
    final change = entered - widget.order.grandTotal;
    setState(() {
      _cashReceived = entered;
      _change = change >= 0 ? change : 0.0;
      _errorMsg = change < 0 ? "Insufficient cash (Required: Rs. ${widget.order.grandTotal.toStringAsFixed(0)})" : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Confirm Handover Payment", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Please specify the payment status for this order handover.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text("UNPAID HANDOVER"),
                    selected: _paymentMode == "unpaid",
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _paymentMode = "unpaid";
                          _errorMsg = null;
                        });
                      }
                    },
                    selectedColor: Colors.orange.withOpacity(0.2),
                    checkmarkColor: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text("PAID (COLLECT CASH)"),
                    selected: _paymentMode == "paid",
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _paymentMode = "paid";
                          _calculateChange();
                        });
                      }
                    },
                    selectedColor: Colors.green.withOpacity(0.2),
                    checkmarkColor: Colors.green,
                  ),
                ),
              ],
            ),
            if (_paymentMode == "paid") ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Grand Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Rs. ${widget.order.grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Cash Received (Rs.)",
                  prefixIcon: Icon(Icons.payments),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Change to Return:"),
                  Text("Rs. ${_change.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _paymentMode == "unpaid"
                ? Colors.orange
                : (_errorMsg == null && _cashReceived >= widget.order.grandTotal ? Colors.green : Colors.grey.shade400),
            foregroundColor: Colors.white,
          ),
          onPressed: _paymentMode == "unpaid" || (_errorMsg == null && _cashReceived >= widget.order.grandTotal)
              ? () {
                  Navigator.pop(context, {
                    'status': _paymentMode, // unpaid or paid
                    'cashReceived': _paymentMode == "paid" ? _cashReceived : widget.order.grandTotal,
                    'change': _paymentMode == "paid" ? _change : 0.0,
                  });
                }
              : null,
          child: Text(
            _paymentMode == "unpaid" ? "CONFIRM UNPAID" : "CONFIRM PAID & COMPLETE",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class PayBillDialog extends StatefulWidget {
  final OrderModel order;

  const PayBillDialog({super.key, required this.order});

  @override
  State<PayBillDialog> createState() => _PayBillDialogState();
}

class _PayBillDialogState extends State<PayBillDialog> {
  final _cashController = TextEditingController();
  double _cashReceived = 0.0;
  double _change = 0.0;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _cashController.removeListener(_calculateChange);
    _cashController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final val = _cashController.text.trim();
    if (val.isEmpty) {
      setState(() {
        _cashReceived = 0.0;
        _change = 0.0;
        _errorMsg = null;
      });
      return;
    }
    final entered = double.tryParse(val);
    if (entered == null) {
      setState(() {
        _errorMsg = "Please enter a valid number";
      });
      return;
    }
    final change = entered - widget.order.grandTotal;
    setState(() {
      _cashReceived = entered;
      _change = change >= 0 ? change : 0.0;
      _errorMsg = change < 0 ? "Insufficient cash (Required: Rs. ${widget.order.grandTotal.toStringAsFixed(0)})" : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text("Pay Bill - Order #${widget.order.orderId}", style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Grand Total:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Rs. ${widget.order.grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Cash Received (Rs.)",
              prefixIcon: Icon(Icons.payments),
              border: OutlineInputBorder(),
              hintText: "e.g., 500",
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Change to Return:", style: TextStyle(fontSize: 14)),
              Text("Rs. ${_change.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
            ],
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _errorMsg == null && _cashReceived >= widget.order.grandTotal ? Colors.green : Colors.grey.shade400,
            foregroundColor: Colors.white,
          ),
          onPressed: _errorMsg == null && _cashReceived >= widget.order.grandTotal
              ? () {
                  Navigator.pop(context, {
                    'cashReceived': _cashReceived,
                    'change': _change,
                  });
                }
              : null,
          child: const Text("CONFIRM PAYMENT", style: TextStyle(fontWeight: FontWeight.bold)),
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

class AddDailyClosingDialog extends StatefulWidget {
  final int totalPunchOrders;
  final int cancelledOrders;

  const AddDailyClosingDialog({
    super.key,
    required this.totalPunchOrders,
    required this.cancelledOrders,
  });

  @override
  State<AddDailyClosingDialog> createState() => _AddDailyClosingDialogState();
}

class _AddDailyClosingDialogState extends State<AddDailyClosingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cashController = TextEditingController();
  final _onlineController = TextEditingController();
  final _cardController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    _onlineController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Perform Daily Closing", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: "Cash Amount (Rs.)",
                placeholder: "e.g., 45000",
                controller: _cashController,
                prefixIcon: Icons.money,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Cash amount is required";
                  if (double.tryParse(val) == null || double.parse(val) < 0) return "Enter a valid amount";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: "Online Banking Payment (Rs.)",
                placeholder: "e.g., 2000",
                controller: _onlineController,
                prefixIcon: Icons.account_balance,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Online amount is required";
                  if (double.tryParse(val) == null || double.parse(val) < 0) return "Enter a valid amount";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: "Card Payment (Rs.)",
                placeholder: "e.g., 2500",
                controller: _cardController,
                prefixIcon: Icons.credit_card,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Card amount is required";
                  if (double.tryParse(val) == null || double.parse(val) < 0) return "Enter a valid amount";
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'cash': double.parse(_cashController.text.trim()),
                'online': double.parse(_onlineController.text.trim()),
                'card': double.parse(_cardController.text.trim()),
              });
            }
          },
          child: const Text("CONFIRM CLOSING", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}

class ViewDailyClosingDialog extends StatelessWidget {
  final DailyClosingModel closing;
  final VoidCallback onPrint;

  const ViewDailyClosingDialog({
    super.key,
    required this.closing,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final double totalReceived = closing.cashAmount + closing.onlineAmount + closing.cardAmount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Daily Closing Details", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text("Logical Date"),
              trailing: Text(closing.id, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text("Closed By"),
              trailing: Text(closing.closedByName, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              title: const Text("Total Punch Orders"),
              trailing: Text("${closing.totalPunchOrders}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text("Total Confirmed Orders"),
              trailing: Text("${closing.totalConfirmedOrders}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text("Cancelled Orders"),
              trailing: Text("${closing.cancelledOrders}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text("Total Today Revenue"),
              trailing: Text("Rs. ${closing.totalTodayRevenue.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              title: const Text("Total Cash"),
              trailing: Text("Rs. ${closing.cashAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            ListTile(
              title: const Text("Online Payment"),
              trailing: Text("Rs. ${closing.onlineAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text("Card Payment"),
              trailing: Text("Rs. ${closing.cardAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              title: const Text("Total Received Amount"),
              trailing: Text("Rs. ${totalReceived.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CLOSE", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          icon: const Icon(Icons.print, color: Colors.white),
          label: const Text("PRINT RECEIPT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          onPressed: () {
            Navigator.pop(context);
            onPrint();
          },
        ),
      ],
    );
  }
}
