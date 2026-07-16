import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/manager_providers.dart';

// Helper for dates matching (using 5 AM logical day boundary)
bool _isSameDay(DateTime orderTime, DateTime selectedDate) {
  final local = orderTime.toLocal();
  final logicalDate = local.hour < 5
      ? DateTime(local.year, local.month, local.day).subtract(const Duration(days: 1))
      : DateTime(local.year, local.month, local.day);
  final sel = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  return logicalDate == sel;
}

class _CustomerContact {
  final String name;
  final String phone;
  final String orderType;
  final String address;

  _CustomerContact({
    required this.name,
    required this.phone,
    required this.orderType,
    required this.address,
  });
}

class DailyDetailsView extends ConsumerStatefulWidget {
  const DailyDetailsView({super.key});

  @override
  ConsumerState<DailyDetailsView> createState() => _DailyDetailsViewState();
}

class _DailyDetailsViewState extends ConsumerState<DailyDetailsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _downloadCSV(String csvContent, String filename) {
    try {
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to download CSV: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _exportSoldItems(List<MapEntry<String, int>> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No sold items to export"), backgroundColor: Colors.orange),
      );
      return;
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final buffer = StringBuffer();
    buffer.writeln("Item Name,Quantity Sold");
    for (var entry in items) {
      // Escape commas in names
      final name = entry.key.contains(',') ? '"${entry.key}"' : entry.key;
      buffer.writeln("$name,${entry.value}");
    }
    _downloadCSV(buffer.toString(), "sold_items_$dateStr.csv");
  }

  void _exportCustomers(List<_CustomerContact> customers) {
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No customer details to export"), backgroundColor: Colors.orange),
      );
      return;
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final buffer = StringBuffer();
    buffer.writeln("Customer Name,Mobile Number,Order Type,Delivery Address");
    for (var c in customers) {
      final name = c.name.contains(',') ? '"${c.name}"' : c.name;
      final phone = c.phone.contains(',') ? '"${c.phone}"' : c.phone;
      final type = c.orderType.contains(',') ? '"${c.orderType}"' : c.orderType;
      final addr = c.address.contains(',') ? '"${c.address}"' : c.address;
      buffer.writeln("$name,$phone,$type,$addr");
    }
    _downloadCSV(buffer.toString(), "daily_customers_$dateStr.csv");
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allOrdersStreamProvider);
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Sales Details"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.secondaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.fastfood), text: "Daily Sold Items"),
            Tab(icon: Icon(Icons.contact_phone), text: "Daily Customers"),
          ],
        ),
      ),
      body: ordersAsync.when(
        loading: () => const LoadingWidget(message: "Loading orders data..."),
        error: (err, _) => CustomErrorWidget(message: err.toString()),
        data: (orders) {
          // Filter orders for the selected logical day
          final dayOrders = orders.where((o) => _isSameDay(o.createdAt, _selectedDate)).toList();

          // 1. Calculate Sold Items (excluding cancelled orders)
          final Map<String, int> soldCounts = {};
          final activeOrders = dayOrders.where((o) => o.status != "Cancelled").toList();
          for (var o in activeOrders) {
            for (var i in o.items) {
              soldCounts[i.name] = (soldCounts[i.name] ?? 0) + i.quantity;
            }
            for (var d in o.deals) {
              final dealName = d['name'] ?? 'Unknown Deal';
              soldCounts["Bundle: $dealName"] = (soldCounts["Bundle: $dealName"] ?? 0) + 1;
            }
          }
          final sortedSoldItems = soldCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // 2. Calculate Customer Contact details
          final Map<String, _CustomerContact> uniqueCustomersMap = {};
          for (var o in dayOrders) {
            final phone = o.customerPhone?.trim() ?? '';
            if (phone.isNotEmpty && phone != 'N/A') {
              final name = o.customerName.trim().isEmpty ? 'N/A' : o.customerName.trim();
              final type = o.orderType.toUpperCase();
              final address = (o.orderType.toLowerCase() == 'delivery') ? (o.deliveryAddress ?? '') : '';
              
              // Key by phone. If already present, let the latest order details take precedence
              uniqueCustomersMap[phone] = _CustomerContact(
                name: name,
                phone: phone,
                orderType: type,
                address: address,
              );
            }
          }
          final customerList = uniqueCustomersMap.values.toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date picker control bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Selected Date: $dateStr",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
                                label: const Text("CHANGE DATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: () => _selectDate(context),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Selected Date: $dateStr",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
                                label: const Text("CHANGE DATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: () => _selectDate(context),
                              ),
                            ],
                          ),
                  );
                },
              ),
              const Divider(height: 1),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Sold Items Breakdown
                    _buildSoldItemsTab(sortedSoldItems),
                    
                    // TAB 2: Customer Details
                    _buildCustomersTab(customerList),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSoldItemsTab(List<MapEntry<String, int>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text("No items sold on this date.", style: TextStyle(color: Colors.grey, fontSize: 15)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Daily Sold Items (Sorted by Popularity)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white, size: 18),
                          label: const Text("DOWNLOAD CSV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _exportSoldItems(items),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Daily Sold Items (Sorted by Popularity)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white, size: 18),
                          label: const Text("DOWNLOAD CSV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _exportSoldItems(items),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(AppTheme.primaryColor.withOpacity(0.08)),
                    columns: const [
                      DataColumn(label: Text("Item Name / Description", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Quantity Sold", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: items.map((entry) {
                      final isBundle = entry.key.startsWith("Bundle:");
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  isBundle ? Icons.local_offer : Icons.fastfood,
                                  size: 16,
                                  color: isBundle ? Colors.purple : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: isBundle ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text("${entry.value}x", style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab(List<_CustomerContact> customers) {
    if (customers.isEmpty) {
      return const Center(
        child: Text("No customer contacts registered on this date.", style: TextStyle(color: Colors.grey, fontSize: 15)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Daily Customer Contact List",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white, size: 18),
                          label: const Text("DOWNLOAD CSV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _exportCustomers(customers),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Daily Customer Contact List",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white, size: 18),
                          label: const Text("DOWNLOAD CSV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _exportCustomers(customers),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(AppTheme.primaryColor.withOpacity(0.08)),
                      columns: const [
                        DataColumn(label: Text("Customer Name", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Mobile Number", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Order Type", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Delivery Address", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: customers.map((c) {
                        return DataRow(
                          cells: [
                            DataCell(Text(c.name)),
                            DataCell(Text(c.phone, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.orderType == 'DELIVERY'
                                      ? Colors.purple.shade50
                                      : (c.orderType == 'TAKEAWAY' ? Colors.orange.shade50 : Colors.green.shade50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  c.orderType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: c.orderType == 'DELIVERY'
                                        ? Colors.purple.shade700
                                        : (c.orderType == 'TAKEAWAY' ? Colors.orange.shade700 : Colors.green.shade700),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                c.address.isEmpty ? 'N/A' : c.address,
                                style: TextStyle(
                                  color: c.address.isEmpty ? Colors.grey : AppTheme.textColor,
                                  fontStyle: c.address.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
