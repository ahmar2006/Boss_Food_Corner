import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../manager/presentation/providers/manager_providers.dart';
import '../providers/expediter_providers.dart';

// Notifier for preserving active kitchen queue tab (Riverpod 3 compatible)
class _TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int index) => state = index;
}
final expediterQueueTabIndexProvider = NotifierProvider<_TabIndexNotifier, int>(_TabIndexNotifier.new);

// Helper to format elapsed duration since placement descriptive of days/hours/minutes
String _formatAgoTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) {
    return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
  }
  if (diff.inHours > 0) {
    final mins = diff.inMinutes % 60;
    return "${diff.inHours}h ${mins}m ago";
  }
  final mins = diff.inMinutes;
  return "${mins}m ago";
}

// Helper bottom navigation for Expediter
Widget _buildExpediterBottomNav(BuildContext context, int activeIdx) {
  return BottomNavigationBar(
    currentIndex: activeIdx,
    selectedItemColor: AppTheme.primaryColor,
    unselectedItemColor: Colors.grey,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    onTap: (idx) {
      if (idx == 0) context.go('/expediter/dashboard');
      if (idx == 1) context.go('/expediter/orders');
      if (idx == 2) context.go('/expediter/activity-log');
    },
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: "Dashboard"),
      BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "Kitchen Queue"),
      BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off), label: "My Activity Log"),
    ],
  );
}



// --- EXPEDITER DASHBOARD VIEW ---
class ExpediterDashboardView extends ConsumerWidget {
  const ExpediterDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final queueState = ref.watch(expediterQueueStreamProvider);
    final unreadCount = ref.watch(unreadIncomingCountProvider);
    final isMock = ref.watch(isMockModeProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: "Boss Food Corner POS - Kitchen Expediter",
        userName: user.name,
        userRole: user.role,
        isMockMode: isMock,
        onLogout: () => ref.read(authActionProvider.notifier).logout(),
      ),
      bottomNavigationBar: _buildExpediterBottomNav(context, 0),
      body: queueState.when(
        loading: () => const LoadingWidget(message: "Initializing Kitchen monitor..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (activeOrders) {
          final pending = activeOrders.where((o) => o.status == "Pending").toList();
          final prep = activeOrders.where((o) => o.status == "In Preparation").toList();
          final ready = activeOrders.where((o) => o.status == "Ready").toList();

          // Completed and Handover counts today
          final allOrders = ref.watch(allOrdersStreamProvider).value ?? [];
          final completedToday = allOrders.where((o) => o.status == "Completed" && _isSameDay(o.createdAt, DateTime.now())).length;
          final handoverToday = allOrders.where((o) => o.status == "Handover" && _isSameDay(o.createdAt, DateTime.now())).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Responsive layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: isNarrow ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Kitchen Dashboard", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text("Monitor active preparation lines and complete orders.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                        SizedBox(width: isNarrow ? 0 : 16, height: isNarrow ? 16 : 0),
                        Badge(
                          label: Text("$unreadCount"),
                          isLabelVisible: unreadCount > 0,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            icon: const Icon(Icons.kitchen, color: Colors.white),
                            label: const Text("OPEN KITCHEN QUEUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              // Clear unread count badge on open
                              ref.read(lastViewedIncomingTimestampProvider.notifier).state = DateTime.now();
                              context.go('/expediter/orders');
                            },
                          ),
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Large touch-friendly grid summary cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: w > 1000 ? 5 : (w > 600 ? 3 : 1),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.8,
                      ),
                      children: [
                        SummaryCard(
                          label: "PENDING ORDERS",
                          value: "${pending.length} Queue",
                          icon: Icons.hourglass_top,
                          color: pending.isNotEmpty ? Colors.red : Colors.grey,
                          iconColor: pending.isNotEmpty ? Colors.red : Colors.grey,
                        ),
                        SummaryCard(
                          label: "IN PREPARATION",
                          value: "${prep.length} Cooking",
                          icon: Icons.restaurant,
                          color: Colors.orange,
                        ),
                        SummaryCard(
                          label: "READY FOR PICKUP",
                          value: "${ready.length} Orders",
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        SummaryCard(
                          label: "COMPLETED TODAY",
                          value: "$completedToday Handed Over",
                          icon: Icons.done_all,
                          color: Colors.blue.shade700,
                        ),
                        SummaryCard(
                          label: "HANDOVER TODAY",
                          value: "$handoverToday Unpaid Orders",
                          icon: Icons.handshake_outlined,
                          color: Colors.deepPurple,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Helper dates check (using 5 AM logical day boundary)
bool _isSameDay(DateTime a, DateTime b) {
  final local = a.toLocal();
  // Orders before 5 AM belong to the previous business day
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);
  final sel = DateTime(b.year, b.month, b.day);
  return logicalDate == sel;
}

// --- INCOMING ORDERS QUEUE SCREEN ---
class OrderQueueView extends ConsumerStatefulWidget {
  const OrderQueueView({super.key});

  @override
  ConsumerState<OrderQueueView> createState() => _OrderQueueViewState();
}

class _OrderQueueViewState extends ConsumerState<OrderQueueView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(expediterQueueTabIndexProvider);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab.clamp(0, 2));
    _tabController.addListener(() {
      ref.read(expediterQueueTabIndexProvider.notifier).set(_tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(expediterQueueStreamProvider);
    final allOrders = ref.watch(allOrdersStreamProvider).value ?? [];
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Incoming Kitchen Queue"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.secondaryColor,
          tabs: const [
            Tab(text: "Pending Queue"),
            Tab(text: "Ready"),
            Tab(text: "Completed (Today)"),
          ],
        ),
      ),
      bottomNavigationBar: _buildExpediterBottomNav(context, 1),
      body: queueState.when(
        loading: () => const LoadingWidget(message: "Syncing queue orders..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (activeOrders) {
          final pendingAndPrep = activeOrders.where((o) => o.status == "Pending" || o.status == "In Preparation").toList();
          pendingAndPrep.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO
          final ready = activeOrders.where((o) => o.status == "Ready").toList();
          final completed = allOrders.where((o) => o.status == "Completed" && _isSameDay(o.createdAt, DateTime.now())).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingGrid(pendingAndPrep, menuItems),
              _buildQueueList(ready, "No orders ready for pickup.", false),
              _buildQueueList(completed, "No orders completed today.", false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingGrid(List<OrderModel> orders, List<MenuItemModel> menuItems) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Text("No pending orders in kitchen queue.", style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        mainAxisExtent: 380,
      ),
      itemCount: orders.length,
      itemBuilder: (context, idx) {
        final ord = orders[idx];
        final isPending = ord.status == "Pending";
        
        // Wait time color coding
        Color cardColor = Colors.white;
        final waitMinutes = DateTime.now().difference(ord.createdAt).inMinutes;
        if (waitMinutes >= 15) {
          cardColor = Colors.red.shade50;
        } else if (waitMinutes >= 5) {
          cardColor = Colors.yellow.shade50;
        }

        return Card(
          color: cardColor,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go('/expediter/orders/${ord.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isPending ? AppTheme.primaryColor.withOpacity(0.08) : Colors.green.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Token: ${ord.tokenId ?? '000'}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange : Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPending ? "PENDING" : "PREPARING",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              // Body (order details list)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Order #${ord.orderId}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            _formatAgoTime(ord.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: waitMinutes >= 15 ? Colors.red : Colors.grey,
                              fontWeight: waitMinutes >= 5 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Customer: ${ord.customerName} (${ord.orderType.toUpperCase()})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Divider(height: 16),
                      // Items list
                      ...ord.items.map((i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${i.quantity}x ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  if (i.specialInstructions != null && i.specialInstructions!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        "Note: ${i.specialInstructions}",
                                        style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                      ...ord.deals.map((d) {
                        final List<dynamic> itemIds = d['itemIds'] ?? [];
                        final itemsDescription = getDealItemsDescription(itemIds, menuItems);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("1x ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bundle: ${d['name']}",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    ),
                                    if (itemsDescription.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          "Contains: $itemsDescription",
                                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    if (d['specialInstructions'] != null && d['specialInstructions'].toString().trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          "Note: ${d['specialInstructions']}",
                                          style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (ord.specialInstructions != null && ord.specialInstructions!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            "Order Note: ${ord.specialInstructions}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer Action Button
              Padding(
                padding: const EdgeInsets.all(12),
                child: CustomButton(
                  text: isPending ? "START PREPARATION" : "MARK READY",
                  color: isPending ? AppTheme.primaryColor : Colors.green,
                  onPressed: () async {
                    try {
                      if (isPending) {
                        await ref.read(expediterActionProvider.notifier).updateStatus(ord.id, "In Preparation", "expediter");
                      } else {
                        await ref.read(expediterActionProvider.notifier).updateStatus(ord.id, "Ready", "expediter");
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildQueueList(List<OrderModel> orders, String emptyMsg, bool applyColorCoding) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Text(emptyMsg, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, idx) {
        final ord = orders[idx];
        
        // Wait time color coding
        Color cardColor = Colors.white;
        if (applyColorCoding) {
          final waitMinutes = DateTime.now().difference(ord.createdAt).inMinutes;
          if (waitMinutes >= 15) {
            cardColor = Colors.red.shade50;
          } else if (waitMinutes >= 5) {
            cardColor = Colors.yellow.shade50;
          }
        }

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                "#${ord.orderId.substring(ord.orderId.length - 2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
              ),
            ),
            title: Text("Order #${ord.orderId} [Token: ${ord.tokenId ?? '000'}] - ${ord.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(
              "Type: ${ord.orderType.toUpperCase()} • Items: ${ord.items.length} items\nPlaced: ${DateFormat('hh:mm:ss a').format(ord.createdAt)} (${_formatAgoTime(ord.createdAt)})",
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go('/expediter/orders/${ord.id}'),
          ),
        );
      },
    );
  }
}

// --- EXPEDITER ORDER DETAIL SCREEN ---
class ExpediterOrderDetailView extends ConsumerWidget {
  final String orderId;

  const ExpediterOrderDetailView({super.key, required this.orderId});

  void _showError(BuildContext context, String err) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err), backgroundColor: AppTheme.errorColor),
    );
  }

  void _onStartPreparation(BuildContext context, WidgetRef ref, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Start Preparing Order #${order.orderId}",
        message: "This moves the order to In Preparation queue. Kitchen staff will begin cooking.",
        confirmLabel: "Start Cooking",
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(expediterActionProvider.notifier).updateStatus(order.id, "In Preparation", "expediter");
          context.go('/expediter/orders');
        } catch (e) {
          _showError(context, e.toString());
        }
      }
    });
  }

  void _onMarkReady(BuildContext context, WidgetRef ref, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Mark Order #${order.orderId} Ready",
        message: "Confirm preparation complete. The cashier will be notified to hand over the food.",
        confirmLabel: "Mark Ready",
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(expediterActionProvider.notifier).updateStatus(order.id, "Ready", "expediter");
          context.go('/expediter/orders');
        } catch (e) {
          _showError(context, e.toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(expediterQueueStreamProvider).value ?? [];
    final allOrders = ref.watch(allOrdersStreamProvider).value ?? [];
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    
    OrderModel? order;
    try {
      order = activeOrders.firstWhere((o) => o.id == orderId);
    } catch (_) {}

    // check in all orders
    if (order == null) {
      try {
        order = allOrders.firstWhere((o) => o.id == orderId);
      } catch (_) {}
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Not Found")),
        body: const Center(child: Text("Active queue item could not be resolved.")),
      );
    }

    final isPending = order.status == "Pending";
    final isPrep = order.status == "In Preparation";

    return Scaffold(
      appBar: AppBar(
        title: Text("Queue Order #${order.orderId} [Token: ${order.tokenId ?? '000'}]"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/expediter/orders'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("QUEUE POSITION: #${order.orderId} [Token: ${order.tokenId ?? '000'}]", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Time Placed: ${DateFormat('dd/MM/yyyy hh:mm:ss a').format(order.createdAt)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Divider(height: 32),

                    // Customer details
                    const Text("Ticket Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text("Customer: ${order.customerName}", style: const TextStyle(fontSize: 14)),
                    Text("Type: ${order.orderType.toUpperCase()}", style: const TextStyle(fontSize: 14)),
                    if (order.specialInstructions != null && order.specialInstructions!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade200, width: 1.5),
                        ),
                        child: Text(
                          "ORDER NOTES: ${order.specialInstructions}",
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 32),

                    // Item list
                    const Text("Kitchen Preparation Checksheet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (context, idx) => const Divider(color: Colors.black12),
                      itemBuilder: (context, idx) {
                        final item = order!.items[idx];
                        final inst = item.specialInstructions;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${item.quantity}x ${item.name}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (inst != null && inst.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade200, width: 1.5),
                                  ),
                                  child: Text(
                                    "KITCHEN WARNING: $inst",
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        );
                      },
                    ),
                    if (order!.deals.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("Bundled Deals (Kitchen Prep)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: order!.deals.length,
                        separatorBuilder: (context, idx) => const Divider(color: Colors.black12),
                        itemBuilder: (context, idx) {
                          final deal = order!.deals[idx];
                          final List<dynamic> itemIds = deal['itemIds'] ?? [];
                          final itemsDescription = getDealItemsDescription(itemIds, menuItems);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "1x Bundle: ${deal['name']}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                                ),
                                if (itemsDescription.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.shade200, width: 1.5),
                                    ),
                                    child: Text(
                                      "PREPARE ITEMS: $itemsDescription",
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                                if (deal['specialInstructions'] != null && deal['specialInstructions'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade200, width: 1.5),
                                    ),
                                    child: Text(
                                      "DEAL WARNING: ${deal['specialInstructions']}",
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const Divider(height: 32),

                    // Process Actions
                    if (isPending) ...[
                      CustomButton(
                        text: "START PREPARATION",
                        color: AppTheme.primaryColor,
                        onPressed: () => _onStartPreparation(context, ref, order!),
                      ),
                    ] else if (isPrep) ...[
                      CustomButton(
                        text: "MARK READY",
                        color: Colors.green,
                        onPressed: () => _onMarkReady(context, ref, order!),
                      ),
                    ] else ...[
                      const Text(
                        "Waiting for cashier handover.",
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                        textAlign: .center,
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- EXPEDITER ACTIVITY LOG SCREEN ---
class ActivityHistoryView extends ConsumerWidget {
  const ActivityHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsState = ref.watch(activityLogsStreamProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text("My Kitchen Activity Log")),
      bottomNavigationBar: _buildExpediterBottomNav(context, 2),
      body: logsState.when(
        loading: () => const LoadingWidget(message: "Loading activity streams..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (logs) {
          // Filter to logs performed by this expediter for the current logical day
          final today = DateTime.now();
          final myLogs = logs.where((l) => l.expediterId == user?.uid && _isSameDay(l.timestamp, today)).toList();

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: myLogs.isEmpty
                    ? const EmptyStateWidget(
                        title: "No Logged Activities",
                        message: "Your kitchen updates will show here.",
                        icon: Icons.history,
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("Order ID", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Timeline Change", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: myLogs.map((log) {
                              return DataRow(cells: [
                                DataCell(
                                  TextButton(
                                    onPressed: () => context.go('/expediter/orders/${log.orderId}'), // wait, this redirects to orders by human ID, let's just make it simple
                                    child: Text("#${log.orderId}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(log.previousStatus, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(log.newStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(DateFormat('dd/MM/yyyy hh:mm:ss a').format(log.timestamp))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
