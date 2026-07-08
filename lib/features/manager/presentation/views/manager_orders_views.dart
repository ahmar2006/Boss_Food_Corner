import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/manager_providers.dart';

// --- Order List History Screen ---
class OrderListView extends ConsumerStatefulWidget {
  const OrderListView({super.key});

  @override
  ConsumerState<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends ConsumerState<OrderListView> {
  String _searchQuery = "";
  String _statusFilter = "All"; // All, Pending, In Preparation, Ready, Completed, Cancelled
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(allOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Order History"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      body: ordersState.when(
        loading: () => const LoadingWidget(message: "Loading orders log..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          // Client side search and filters
          final filtered = orders.where((order) {
            // Search match
            final query = _searchQuery.trim().toLowerCase();
            final matchesQuery = query.isEmpty ||
                order.orderId.contains(query) ||
                order.customerName.toLowerCase().contains(query);

            // Status match
            final matchesStatus = _statusFilter == "All" || order.status.toLowerCase() == _statusFilter.toLowerCase();

            // Date match
            bool matchesDate = true;
            if (_dateRange != null) {
              final date = order.createdAt;
              // Make range dates start and end inclusive
              final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
              final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
              matchesDate = date.isAfter(start) && date.isBefore(end);
            }

            return matchesQuery && matchesStatus && matchesDate;
          }).toList();

          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SearchBarWidget(
                            placeholder: "Search by Order ID or Customer Name...",
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: "Status Filter",
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: "All", child: Text("All Statuses")),
                              DropdownMenuItem(value: "Pending", child: Text("Pending")),
                              DropdownMenuItem(value: "In Preparation", child: Text("In Preparation")),
                              DropdownMenuItem(value: "Ready", child: Text("Ready")),
                              DropdownMenuItem(value: "Completed", child: Text("Completed")),
                              DropdownMenuItem(value: "Cancelled", child: Text("Cancelled")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _statusFilter = val ?? "All";
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          icon: const Icon(Icons.date_range),
                          label: Text(_dateRange == null
                              ? "Filter by Date"
                              : "${DateFormat.yMMMd().format(_dateRange!.start)} - ${DateFormat.yMMMd().format(_dateRange!.end)}"),
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2025),
                              lastDate: DateTime.now(),
                              initialDateRange: _dateRange,
                            );
                            if (picked != null) {
                              setState(() {
                                _dateRange = picked;
                              });
                            }
                          },
                        ),
                        if (_dateRange != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _dateRange = null;
                              });
                            },
                          )
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: filtered.isEmpty
                          ? const EmptyStateWidget(
                              title: "No Orders Logged",
                              message: "No orders found matching the filter criteria.",
                              icon: Icons.history_edu_outlined,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text("Order ID", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Customer", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Type", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: filtered.map((ord) {
                                    return DataRow(cells: [
                                      DataCell(Text("#${ord.orderId}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(ord.customerName)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              ord.orderType == "dine-in"
                                                  ? Icons.restaurant
                                                  : (ord.orderType == "takeaway" ? Icons.shopping_bag : Icons.delivery_dining),
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(ord.orderType.toUpperCase(), style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(ord.createdAt))),
                                      DataCell(Text("Rs. ${ord.grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(StatusBadge(status: ord.status)),
                                      DataCell(
                                        TextButton.icon(
                                          icon: const Icon(Icons.info_outline, size: 16),
                                          label: const Text("Details"),
                                          onPressed: () {
                                            if (GoRouterState.of(context).uri.toString().startsWith('/manager')) {
                                              context.go('/manager/orders/${ord.id}');
                                            } else {
                                              context.go('/cashier/receipt/${ord.id}');
                                            }
                                          },
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
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

// --- Order Detail Screen ---
class OrderDetailView extends ConsumerWidget {
  final String orderId;

  const OrderDetailView({super.key, required this.orderId});

  void _showError(BuildContext context, String err) {
    String cleanErr = err.replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanErr),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onCancelOrder(BuildContext context, WidgetRef ref, OrderModel order, String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Cancel Order #${order.orderId}",
        message: "Are you sure you want to cancel this order? This action will set the status to Cancelled.",
        inputLabel: "Reason for Cancellation",
        inputPlaceholder: "Customer changed mind, wrong items, etc...",
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(allOrdersStreamProvider).value ?? [];
    final currentUserId = ref.watch(authStateProvider).value?.uid ?? '';
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    
    OrderModel? order;
    try {
      order = orders.firstWhere((o) => o.id == orderId);
    } catch (_) {}

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Not Found")),
        body: const Center(child: Text("Specified order record could not be loaded.")),
      );
    }

    final canCancel = order.status != "Cancelled" && order.status != "Completed";

    return Scaffold(
      appBar: AppBar(
        title: Text("Order Details - #${order.orderId} [Token: ${order.tokenId ?? '000'}]"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/orders'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Card Details left
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("ORDER #${order.orderId} [Token: ${order.tokenId ?? '000'}]", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Date: ${DateFormat('dd/MM/yyyy hh:mm:ss a').format(order.createdAt)}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  Text("Cashier: ${order.cashierName}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                              StatusBadge(status: order.status),
                            ],
                          ),
                          const Divider(height: 32),
                          
                          // Customer Card Info
                          const Text("Customer Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text("Name: ${order.customerName}", style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                order.orderType == "dine-in"
                                    ? Icons.restaurant
                                    : (order.orderType == "takeaway" ? Icons.shopping_bag : Icons.delivery_dining),
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text("Type: ${order.orderType.toUpperCase()}", style: const TextStyle(fontSize: 14)),
                              if (order.orderType == "dine-in" && order.tableNumber != null) ...[
                                const SizedBox(width: 16),
                                const Icon(Icons.table_restaurant, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text("Table: ${order.tableNumber}", style: const TextStyle(fontSize: 14)),
                              ]
                            ],
                          ),
                          if (order.orderType == "delivery") ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone_android, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text("Phone: ${order.customerPhone ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Address: ${order.deliveryAddress ?? 'N/A'}",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 32),

                          // Items List
                          const Text("Ordered Items Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: order!.items.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.black12),
                            itemBuilder: (context, idx) {
                              final item = order!.items[idx];
                              final inst = item.specialInstructions;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "${item.quantity}x ${item.name}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          "Rs. ${item.totalPrice.toStringAsFixed(2)}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "Unit Price: Rs. ${item.unitPrice.toStringAsFixed(2)}",
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    if (inst != null && inst.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Text(
                                          "Instructions: $inst",
                                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                      )
                                    ]
                                  ],
                                ),
                              );
                            },
                          ),
                          if (order!.deals.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text("Bundled Deals Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: order!.deals.length,
                              separatorBuilder: (context, index) => const Divider(color: Colors.black12),
                              itemBuilder: (context, idx) {
                                final deal = order!.deals[idx];
                                final List<dynamic> itemIds = deal['itemIds'] ?? [];
                                final itemsDescription = getDealItemsDescription(itemIds, menuItems);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "1x Bundle: ${deal['name']}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                                          ),
                                          Text(
                                            "Rs. ${double.tryParse(deal['price']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      if (itemsDescription.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "Contains: $itemsDescription",
                                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          const Divider(height: 32),

                          // Billing Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Subtotal"),
                              Text("Rs. ${order.subtotal.toStringAsFixed(2)}"),
                            ],
                          ),
                          if (order.discountAmount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Campaign Discounts"),
                                Text("- Rs. ${order.discountAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green)),
                              ],
                            ),
                          ],
                          if (order.tax > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Government Tax"),
                                Text("Rs. ${order.tax.toStringAsFixed(2)}"),
                              ],
                            ),
                          ],
                          if (order.deliveryCharges > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Delivery Charges"),
                                Text("Rs. ${order.deliveryCharges.toStringAsFixed(2)}"),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                "Rs. ${order.grandTotal.toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          if (order.status == "Cancelled") ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Cancellation Log", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  const SizedBox(height: 4),
                                  Text("Reason: ${order.cancellationReason ?? 'None'}", style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                                  if (order.cancelledAt != null)
                                    Text("Time: ${DateFormat('dd/MM/yyyy hh:mm:ss a').format(order.cancelledAt!)}", style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],

                          if (canCancel) ...[
                            const SizedBox(height: 8),
                            CustomButton(
                              text: "CANCEL ORDER",
                              color: Colors.red,
                              onPressed: () => _onCancelOrder(context, ref, order!, currentUserId),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (order.isPaid) ...[
                            CustomButton(
                              text: "MARK AS UNPAID",
                              color: Colors.orange,
                              icon: Icons.money_off,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => const ConfirmationDialog(
                                    title: "Mark Order as Unpaid?",
                                    message: "This will allow the cashier to edit this order.",
                                    confirmLabel: "Mark Unpaid",
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(order!.id, false, currentUserId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Order marked as UNPAID successfully! Cashier can now edit.")),
                                    );
                                  } catch (e) {
                                    _showError(context, e.toString());
                                  }
                                }
                              },
                            ),
                          ] else ...[
                            CustomButton(
                              text: "MARK AS PAID",
                              color: Colors.green,
                              icon: Icons.payment,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => const ConfirmationDialog(
                                    title: "Mark Order as Paid?",
                                    message: "This will lock cashier edits for this order.",
                                    confirmLabel: "Mark Paid",
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await ref.read(orderRepositoryProvider).updateOrderPaymentStatus(order!.id, true, currentUserId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Order marked as PAID successfully! Cashier edits are now locked.")),
                                    );
                                  } catch (e) {
                                    _showError(context, e.toString());
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Timeline history right side card
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text("Status History Timeline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(height: 24),
                          ...order.statusHistory.map((hist) {
                            final date = hist['timestamp'] as DateTime;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    radius: 6,
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(hist['status'] ?? 'Pending', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(DateFormat('dd/MM hh:mm:ss a').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
