import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/manager_providers.dart';
import 'menu_views.dart'; // import buildBase64Image

// --- Deal List View ---
class DealListView extends ConsumerStatefulWidget {
  const DealListView({super.key});

  @override
  ConsumerState<DealListView> createState() => _DealListViewState();
}

class _DealListViewState extends ConsumerState<DealListView> {
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

  void _onToggleStatus(DealModel deal) async {
    final updated = deal.copyWith(status: deal.status == "active" ? "disabled" : "active");
    try {
      await ref.read(managerActionProvider.notifier).editDeal(updated);
      final actState = ref.read(managerActionProvider);
      if (actState.hasError) {
        _showError(actState.error.toString());
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _onDeleteDeal(DealModel deal) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Delete Deal",
        message: "Are you sure you want to permanently delete promotional deal '${deal.name}'?",
        confirmLabel: "Delete Permanently",
        isDanger: true,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).deleteDeal(deal.id);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dealsState = ref.watch(dealsStreamProvider);
    final size = MediaQuery.of(context).size;
    final gridCount = size.width > 1200 ? 4 : (size.width > 800 ? 3 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Promotional Deals Configuration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Deal",
        onPressed: () => context.go('/manager/deals/add'),
        child: const Icon(Icons.add),
      ),
      body: dealsState.when(
        loading: () => const LoadingWidget(message: "Loading deals..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(dealsStreamProvider)),
        data: (deals) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: deals.isEmpty
                ? const EmptyStateWidget(
                    title: "No Deals Configured",
                    message: "Tap the '+' button to package items into bundled discounts/deals.",
                    icon: Icons.local_offer_outlined,
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: deals.length,
                    itemBuilder: (context, idx) {
                      final deal = deals[idx];
                      final isActive = deal.status == "active";

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  buildBase64Image(deal.imageBase64),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.green.shade600 : Colors.grey.shade600,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isActive ? "ACTIVE" : "DISABLED",
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deal.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "Bundled items count: ${deal.itemIds.length}",
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                    Text(
                                      "Rs. ${deal.price.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: "Edit Deal",
                                          onPressed: () => context.go('/manager/deals/edit/${deal.id}'),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isActive ? Icons.visibility_off : Icons.visibility,
                                            color: isActive ? Colors.orange : Colors.green,
                                            size: 20,
                                          ),
                                          tooltip: isActive ? "Hide Deal" : "Show Deal",
                                          onPressed: () => _onToggleStatus(deal),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: "Delete Deal",
                                          onPressed: () => _onDeleteDeal(deal),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
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

// --- Deal Add/Edit Form View ---
class DealFormView extends ConsumerStatefulWidget {
  final String? dealId;

  const DealFormView({super.key, this.dealId});

  @override
  ConsumerState<DealFormView> createState() => _DealFormViewState();
}

class _DealFormViewState extends ConsumerState<DealFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _checklistSearchController = TextEditingController();
  final _manualItemController = TextEditingController();

  List<String> _selectedItemIds = [];
  String _imageBase64 = "";
  bool _isActive = true;
  bool _isEditing = false;
  DealModel? _existingDeal;
  String _checklistSearchQuery = "";

  @override
  void initState() {
    super.initState();
    _isEditing = widget.dealId != null;
    if (_isEditing) {
      _loadDeal();
    }
  }

  void _loadDeal() {
    final list = ref.read(dealsStreamProvider).value ?? [];
    try {
      _existingDeal = list.firstWhere((d) => d.id == widget.dealId);
      _nameController.text = _existingDeal!.name;
      _priceController.text = _existingDeal!.price.toString();
      _selectedItemIds = List<String>.from(_existingDeal!.itemIds);
      _imageBase64 = _existingDeal!.imageBase64;
      _isActive = _existingDeal!.status == "active";
    } catch (_) {
      context.go('/manager/deals');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _checklistSearchController.dispose();
    _manualItemController.dispose();
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

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      if (_imageBase64.isEmpty) {
        _showError("Deal display image is required");
        return;
      }


      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text);
      final status = _isActive ? "active" : "disabled";

      final deal = DealModel(
        id: _isEditing ? _existingDeal!.id : '',
        name: name,
        price: price,
        itemIds: _selectedItemIds,
        imageBase64: _imageBase64,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        if (_isEditing) {
          await ref.read(managerActionProvider.notifier).editDeal(deal);
        } else {
          await ref.read(managerActionProvider.notifier).addDeal(deal);
        }

        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          context.go('/manager/deals');
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(managerActionProvider);
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];
    final activeItems = menuItems.where((i) => i.status == "active").toList();

    // Calculate original sum value of items
    double originalTotal = 0;
    for (var itemId in _selectedItemIds) {
      if (itemId.contains("::")) {
        final split = itemId.split("::");
        final mId = split[0];
        final varName = split[1];
        MenuItemModel? match;
        for (final item in activeItems) {
          if (item.id == mId) {
            match = item;
            break;
          }
        }
        if (match != null) {
          MenuItemVariant? variant;
          for (final v in match.variants) {
            if (v.name == varName) {
              variant = v;
              break;
            }
          }
          originalTotal += (variant?.price ?? match.price);
        }
      } else {
        MenuItemModel? match;
        for (final item in activeItems) {
          if (item.id == itemId) {
            match = item;
            break;
          }
        }
        if (match != null) {
          originalTotal += match.price;
        }
      }
    }

    final List<_ChecklistItem> checklistOptions = [];
    for (final item in activeItems) {
      if (item.variants.isEmpty) {
        checklistOptions.add(_ChecklistItem(id: item.id, name: item.name, price: item.price));
      } else {
        for (final v in item.variants) {
          checklistOptions.add(_ChecklistItem(
            id: "${item.id}::${v.name}",
            name: "${item.name} (${v.name})",
            price: v.price ?? item.price,
          ));
        }
      }
    }

    final filteredChecklist = checklistOptions.where((opt) {
      return opt.name.toLowerCase().contains(_checklistSearchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Deal" : "Add Deal"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/deals'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
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
                      Text(
                        _isEditing ? "Modify Deal Bundle" : "Package Promotional Deal",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        label: "Deal Name",
                        placeholder: "e.g., Zinger Combo, Family feast",
                        controller: _nameController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Deal name is required";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Deal Price (Rs.)",
                        placeholder: "e.g., 999.00",
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Deal price is required";
                          final doubleVal = double.tryParse(val);
                          if (doubleVal == null || doubleVal <= 0) return "Enter a valid price greater than 0";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Package Items Checklist",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _checklistSearchController,
                        decoration: InputDecoration(
                          hintText: "Search items...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _checklistSearchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: filteredChecklist.isEmpty
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text("No matching menu items available", style: TextStyle(color: Colors.grey)),
                              ))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredChecklist.length,
                                itemBuilder: (context, idx) {
                                  final item = filteredChecklist[idx];
                                  final qty = _selectedItemIds.where((id) => id == item.id).length;
                                  final isChecked = qty > 0;

                                  return ListTile(
                                    title: Text(item.name),
                                    subtitle: Text("Rs. ${item.price.toStringAsFixed(0)}"),
                                    leading: Checkbox(
                                      value: isChecked,
                                      activeColor: AppTheme.primaryColor,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedItemIds.add(item.id);
                                          } else {
                                            _selectedItemIds.removeWhere((id) => id == item.id);
                                          }
                                        });
                                      },
                                    ),
                                    trailing: isChecked
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                                onPressed: () {
                                                  setState(() {
                                                    final index = _selectedItemIds.indexOf(item.id);
                                                    if (index != -1) {
                                                      _selectedItemIds.removeAt(index);
                                                    }
                                                  });
                                                },
                                              ),
                                              Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedItemIds.add(item.id);
                                                  });
                                                },
                                              ),
                                            ],
                                          )
                                        : null,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CustomTextField(
                                  label: "Add Manual Package Item",
                                  placeholder: "e.g., 1.5L Soft Drink",
                                  controller: _manualItemController,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text("Add Manual Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    final text = _manualItemController.text.trim();
                                    if (text.isNotEmpty) {
                                      setState(() {
                                        _selectedItemIds.add(text);
                                        _manualItemController.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  label: "Add Manual Package Item",
                                  placeholder: "e.g., 1.5L Soft Drink",
                                  controller: _manualItemController,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    final text = _manualItemController.text.trim();
                                    if (text.isNotEmpty) {
                                      setState(() {
                                        _selectedItemIds.add(text);
                                        _manualItemController.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                      const SizedBox(height: 12),
                      // Chips list
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _selectedItemIds.toSet().map((itemId) {
                          final qty = _selectedItemIds.where((id) => id == itemId).length;
                          String displayName = itemId;
                          if (itemId.contains("::")) {
                            final split = itemId.split("::");
                            final mId = split[0];
                            final varName = split[1];
                            MenuItemModel? match;
                            for (final item in activeItems) {
                              if (item.id == mId) {
                                match = item;
                                break;
                              }
                            }
                            if (match != null) {
                              displayName = "${match.name} ($varName)";
                            }
                          } else {
                            MenuItemModel? match;
                            for (final item in activeItems) {
                              if (item.id == itemId) {
                                match = item;
                                break;
                              }
                            }
                            if (match != null) {
                              displayName = match.name;
                            }
                          }
                          return Chip(
                            label: Text("$displayName x$qty"),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedItemIds.removeWhere((id) => id == itemId);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (originalTotal > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Total Individual Price: Rs. ${originalTotal.toStringAsFixed(2)}",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, decoration: TextDecoration.lineThrough),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ImagePickerWidget(
                        initialBase64: _imageBase64,
                        onImageSelected: (base64) {
                          _imageBase64 = base64;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Status Enabled", style: TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: _isActive,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              setState(() {
                                _isActive = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: _isEditing ? "SAVE UPDATES" : "CREATE DEAL",
                        isLoading: actionState.isLoading,
                        onPressed: _onSave,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "CANCEL",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/manager/deals'),
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

// --- Discount List View ---
class DiscountListView extends ConsumerStatefulWidget {
  const DiscountListView({super.key});

  @override
  ConsumerState<DiscountListView> createState() => _DiscountListViewState();
}

class _DiscountListViewState extends ConsumerState<DiscountListView> {
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

  void _onDeleteDiscount(DiscountModel d) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: "Delete Discount Code",
        message: "Are you sure you want to permanently delete '${d.name}'? Past order history using this discount code will not be altered.",
        confirmLabel: "Delete Permanently",
        isDanger: true,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ref.read(managerActionProvider.notifier).deleteDiscount(d.id);
          final actState = ref.read(managerActionProvider);
          if (actState.hasError) {
            _showError(actState.error.toString());
          }
        } catch (e) {
          _showError(e.toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final discountsState = ref.watch(discountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Discount Setup"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: "Add Discount",
        onPressed: () => context.go('/manager/discounts/add'),
        child: const Icon(Icons.add),
      ),
      body: discountsState.when(
        loading: () => const LoadingWidget(message: "Loading discount codes..."),
        error: (err, _) => CustomErrorWidget(message: err.toString(), onRetry: () => ref.refresh(discountsStreamProvider)),
        data: (discounts) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: discounts.isEmpty
                    ? const EmptyStateWidget(
                        title: "No Discounts Created",
                        message: "Create campaigns like Student Discount by clicking the '+' button.",
                        icon: Icons.discount_outlined,
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("Discount Name", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Type", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Value", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: discounts.map((d) {
                              final isPerc = d.type == "percentage";
                              return DataRow(cells: [
                                DataCell(Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text(isPerc ? "Percentage" : "Fixed Amount")),
                                DataCell(Text(isPerc ? "${d.value.toStringAsFixed(1)}%" : "Rs. ${d.value.toStringAsFixed(2)}")),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        tooltip: "Edit Discount",
                                        onPressed: () => context.go('/manager/discounts/edit/${d.id}'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        tooltip: "Delete Discount",
                                        onPressed: () => _onDeleteDiscount(d),
                                      ),
                                    ],
                                  ),
                                ),
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

// --- Discount Add/Edit Form View ---
class DiscountFormView extends ConsumerStatefulWidget {
  final String? discountId;

  const DiscountFormView({super.key, this.discountId});

  @override
  ConsumerState<DiscountFormView> createState() => _DiscountFormViewState();
}

class _DiscountFormViewState extends ConsumerState<DiscountFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();

  String _discountType = "percentage"; // percentage, fixed
  bool _isEditing = false;
  DiscountModel? _existingDiscount;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.discountId != null;
    if (_isEditing) {
      _loadDiscount();
    }
  }

  void _loadDiscount() {
    final list = ref.read(discountsStreamProvider).value ?? [];
    try {
      _existingDiscount = list.firstWhere((d) => d.id == widget.discountId);
      _nameController.text = _existingDiscount!.name;
      _valueController.text = _existingDiscount!.value.toString();
      _discountType = _existingDiscount!.type;
    } catch (_) {
      context.go('/manager/discounts');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
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

  void _onSave() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final value = double.parse(_valueController.text);
      final type = _discountType;

      final disc = DiscountModel(
        id: _isEditing ? _existingDiscount!.id : '',
        name: name,
        type: type,
        value: value,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        if (_isEditing) {
          await ref.read(managerActionProvider.notifier).editDiscount(disc);
        } else {
          await ref.read(managerActionProvider.notifier).addDiscount(disc);
        }

        final actState = ref.read(managerActionProvider);
        if (actState.hasError) {
          _showError(actState.error.toString());
        } else {
          context.go('/manager/discounts');
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
        title: Text(_isEditing ? "Edit Discount" : "Add Discount"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager/discounts'),
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
                      Text(
                        _isEditing ? "Edit Discount Rules" : "Configure Discount Campaign",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        textAlign: .center,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        label: "Discount Name",
                        placeholder: "e.g., Student Discount, Senior Citizen",
                        controller: _nameController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Discount name is required";
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Discount Type",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Radio<String>(
                                    value: "percentage",
                                    groupValue: _discountType,
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        _discountType = val ?? "percentage";
                                      });
                                    },
                                  ),
                                  const Text("Percentage (%)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Radio<String>(
                                    value: "fixed",
                                    groupValue: _discountType,
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        _discountType = val ?? "fixed";
                                      });
                                    },
                                  ),
                                  const Text("Fixed Amount (Rs.)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: _discountType == "percentage" ? "Discount Percentage (%)" : "Discount Flat Amount (Rs.)",
                        placeholder: _discountType == "percentage" ? "e.g., 10.0" : "e.g., 100.00",
                        controller: _valueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Discount value is required";
                          final doubleVal = double.tryParse(val);
                          if (doubleVal == null || doubleVal <= 0) return "Enter a valid value greater than 0";
                          if (_discountType == "percentage" && doubleVal > 100) return "Percentage cannot exceed 100%";
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: _isEditing ? "SAVE UPDATES" : "CREATE CAMPAIGN",
                        isLoading: actionState.isLoading,
                        onPressed: _onSave,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "CANCEL",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/manager/discounts'),
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

class _ChecklistItem {
  final String id;
  final String name;
  final double price;

  _ChecklistItem({required this.id, required this.name, required this.price});
}
