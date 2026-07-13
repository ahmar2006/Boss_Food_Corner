import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../providers/cashier_providers.dart';
import '../../../manager/presentation/providers/manager_providers.dart';

// Helper progress indicator for Checkout Steps
Widget buildStepProgress(int currentStep) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24.0),
    child: Row(
      children: [
        _stepBubble(1, "Customer", currentStep >= 1),
        _stepLine(currentStep >= 2),
        _stepBubble(2, "Discounts", currentStep >= 2),
        _stepLine(currentStep >= 3),
        _stepBubble(3, "Summary", currentStep >= 3),
      ],
    ),
  );
}

Widget _stepBubble(int index, String title, bool active) {
  return Row(
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: active ? AppTheme.primaryColor : Colors.grey.shade300,
        child: Text(
          index.toString(),
          style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? AppTheme.textColor : Colors.grey,
          fontSize: 13,
        ),
      ),
    ],
  );
}

Widget _stepLine(bool active) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 2,
      color: active ? AppTheme.primaryColor : Colors.grey.shade300,
    ),
  );
}

// --- CHECKOUT STEP 1: CUSTOMER DETAILS ---
class CheckoutCustomerView extends ConsumerStatefulWidget {
  const CheckoutCustomerView({super.key});

  @override
  ConsumerState<CheckoutCustomerView> createState() => _CheckoutCustomerViewState();
}

class _CheckoutCustomerViewState extends ConsumerState<CheckoutCustomerView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tableController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String _orderType = "dine-in"; // dine-in, takeaway, delivery

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = ref.read(cartProvider);
      _nameController.text = cart.customerName;
      _orderType = cart.orderType;
      _tableController.text = cart.tableNumber ?? '';
      _addressController.text = cart.deliveryAddress ?? '';
      _phoneController.text = cart.customerPhone ?? '';
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tableController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      final enteredName = _nameController.text.trim();
      ref.read(cartProvider.notifier).updateCustomerDetails(
            name: enteredName.isNotEmpty ? enteredName : "Walk-in Customer",
            type: _orderType,
            table: _orderType == "dine-in" ? _tableController.text.trim() : null,
            address: _orderType == "delivery" ? _addressController.text.trim() : null,
            phone: _orderType == "delivery" ? _phoneController.text.trim() : null,
          );
      context.go('/cashier/checkout/discount');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POS Checkout Wizard"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cashier/pos'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildStepProgress(1),
                      const Text(
                        "Customer Information",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Customer Name (Optional)",
                        placeholder: "e.g., Ahmed Khan",
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            if (val.trim().length < 2) return "Must be at least 2 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Order Service Type",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _orderType,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: "Table Number (Optional)",
                          placeholder: "e.g., Table 5",
                          controller: _tableController,
                          prefixIcon: Icons.table_restaurant,
                        ),
                      ],
                      if (_orderType == "delivery") ...[
                        const SizedBox(height: 16),
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
                              return "Enter a valid 11 digit Pakistani number (03XXXXXXXXX)";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      CustomButton(
                        text: "NEXT: DISCOUNTS",
                        onPressed: _onNext,
                        icon: Icons.navigate_next,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "BACK TO CART",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/cashier/pos'),
                      )
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

// --- CHECKOUT STEP 2: DISCOUNT SELECTION ---
class CheckoutDiscountView extends ConsumerStatefulWidget {
  const CheckoutDiscountView({super.key});

  @override
  ConsumerState<CheckoutDiscountView> createState() => _CheckoutDiscountViewState();
}

class _CheckoutDiscountViewState extends ConsumerState<CheckoutDiscountView> {
  final _manualController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = ref.read(cartProvider);
      if (cart.manualDiscount != 0.0) {
        _manualController.text = cart.manualDiscount.abs().toString();
      }
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      if (_manualController.text.isNotEmpty) {
        final val = double.tryParse(_manualController.text) ?? 0.0;
        ref.read(cartProvider.notifier).applyManualDiscount(val);
      } else {
        ref.read(cartProvider.notifier).applyManualDiscount(0.0);
      }
      context.go('/cashier/checkout/summary');
    }
  }

  @override
  Widget build(BuildContext context) {
    final discountsState = ref.watch(discountsStreamProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Apply Discounts"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cashier/checkout/customer'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildStepProgress(2),
                      const Text(
                        "Available Discounts ",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 8),
                      
                      // Active discounts
                      discountsState.when(
                        loading: () => const LinearProgressIndicator(color: AppTheme.primaryColor),
                        error: (err, _) => Text("Failed to load campaign discounts: $err", style: const TextStyle(color: Colors.red)),
                        data: (discounts) {
                          if (discounts.isEmpty) {
                            return const Text("No  discounts configured.", style: TextStyle(color: Colors.grey, fontSize: 13));
                          }
                          return Column(
                            children: discounts.map((d) {
                              final isSelected = cart.appliedManagerDiscount?.id == d.id;
                              final isPerc = d.type == "percentage";
                              return Card(
                                color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  trailing: Text(
                                    isPerc ? "${d.value.toStringAsFixed(0)}%" : "Rs. ${d.value.toStringAsFixed(0)}",
                                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  leading: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_off,
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
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
                      const Divider(height: 32),
                      
                      const Text(
                        "Add Manual Discount",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
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
                      // const SizedBox(height: 6),
                      // Text(
                      //   "Manual discount directly reduces revenue. Use manager discounts when possible.",
                      //   style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontStyle: FontStyle.italic),
                      // ),
                      const Divider(height: 32),

                      // Aggregates preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Subtotal:"),
                          Text("Rs. ${cart.itemsSubtotal.toStringAsFixed(2)}"),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: "NEXT: SUMMARY & PAY",
                        onPressed: _onNext,
                        icon: Icons.navigate_next,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: "BACK",
                        isOutlined: true,
                        color: Colors.grey,
                        onPressed: () => context.go('/cashier/checkout/customer'),
                      )
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

// --- CHECKOUT STEP 3: ORDER SUMMARY & PAYMENT ---
class CheckoutSummaryView extends ConsumerStatefulWidget {
  const CheckoutSummaryView({super.key});

  @override
  ConsumerState<CheckoutSummaryView> createState() => _CheckoutSummaryViewState();
}

class _CheckoutSummaryViewState extends ConsumerState<CheckoutSummaryView> {

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

  void _onConfirm(SettingsModel settings, double grandTotal) async {
    ref.read(cartProvider.notifier).updatePaymentDetails(grandTotal);

    try {
      await ref.read(cashierActionProvider.notifier).submitOrder(settings);
      final actionState = ref.read(cashierActionProvider);
      if (actionState.hasError) {
        _showError(actionState.error.toString());
      } else {
        final orderDocId = actionState.value ?? '';
        context.go('/cashier/receipt/$orderDocId');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }



  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final settings = ref.watch(settingsStreamProvider).value;
    final actionState = ref.watch(cashierActionProvider);
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Bill Math
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
    double totalDiscount = managerD + manualD;

    double baseForTax = subtotal - totalDiscount;
    if (baseForTax < 0) baseForTax = 0;

    double tax = baseForTax * (settings.taxRate / 100);
    double delivery = cart.orderType == "delivery" ? settings.deliveryCharges : 0.0;
    double grandTotal = baseForTax + tax + delivery;



    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Review & Checkout"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cashier/checkout/discount'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Builder(
              builder: (context) {
                final size = MediaQuery.of(context).size;
                final isDesktopLayout = size.width > 760;

                final summaryCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildStepProgress(3),
                        const Text(
                          "Bill Breakdown & Summary",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Customer: ${cart.customerName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("Order Type: ${cart.orderType.toUpperCase()}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (cart.orderType == "delivery") ...[
                                Text("Phone: ${cart.customerPhone}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text("Address: ${cart.deliveryAddress}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cart.items.length,
                          itemBuilder: (context, idx) {
                            final item = cart.items[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${item.quantity}x ${item.item.name}", style: const TextStyle(fontSize: 13)),
                                  Text("Rs. ${item.totalPrice.toStringAsFixed(2)}"),
                                ],
                              ),
                            );
                          },
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cart.deals.length,
                          itemBuilder: (context, idx) {
                            final deal = cart.deals[idx];
                            final itemsDescription = getDealItemsDescription(deal.itemIds, menuItems);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("1x Bundle: ${deal.name}", style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                      Text("Rs. ${deal.price.toStringAsFixed(2)}"),
                                    ],
                                  ),
                                  if (itemsDescription.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                      child: Text(
                                        "Contains: $itemsDescription",
                                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Subtotal"),
                            Text("Rs. ${subtotal.toStringAsFixed(2)}"),
                          ],
                        ),
                        if (totalDiscount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Discounts Applied"),
                              Text("- Rs. ${totalDiscount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                        ],
                        if (tax > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Taxes (${settings.taxRate.toStringAsFixed(1)}%)"),
                              Text("Rs. ${tax.toStringAsFixed(2)}"),
                            ],
                          ),
                        ],
                        if (delivery > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Delivery Charges"),
                              Text("Rs. ${delivery.toStringAsFixed(2)}"),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              "Rs. ${grandTotal.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                final confirmationCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Order Confirmation",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                        const Divider(height: 20),
                        const Text(
                          "Please review the bill breakdown and customer information. Once verified, click below to confirm and finalize this order in the system.",
                          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                        ),
                        const SizedBox(height: 48),
                        CustomButton(
                          text: "CONFIRM & SUBMIT ORDER",
                          isLoading: actionState.isLoading,
                          onPressed: () => _onConfirm(settings, grandTotal),
                          icon: Icons.check,
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: "BACK",
                          isOutlined: true,
                          color: Colors.grey,
                          onPressed: () => context.go('/cashier/checkout/discount'),
                        )
                      ],
                    ),
                  ),
                );

                return Flex(
                  direction: isDesktopLayout ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isDesktopLayout ? Expanded(flex: 5, child: summaryCard) : summaryCard,
                    isDesktopLayout ? const SizedBox(width: 24) : const SizedBox(height: 16),
                    isDesktopLayout ? Expanded(flex: 4, child: confirmationCard) : confirmationCard,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
