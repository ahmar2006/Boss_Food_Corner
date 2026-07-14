import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class CartItem {
  final MenuItemModel item;
  final int quantity;
  final String? specialInstructions;
  final MenuItemVariant? selectedVariant;

  CartItem({
    required this.item,
    this.quantity = 1,
    this.specialInstructions,
    this.selectedVariant,
  });

  CartItem copyWith({
    MenuItemModel? item,
    int? quantity,
    String? specialInstructions,
    MenuItemVariant? selectedVariant,
  }) {
    return CartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      selectedVariant: selectedVariant ?? this.selectedVariant,
    );
  }

  double get totalPrice => (selectedVariant?.price ?? item.price) * quantity;
}

class CartDeal {
  final DealModel deal;
  final String? specialInstructions;

  CartDeal({
    required this.deal,
    this.specialInstructions,
  });

  CartDeal copyWith({
    DealModel? deal,
    String? specialInstructions,
  }) {
    return CartDeal(
      deal: deal ?? this.deal,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  double get price => deal.price;
}

class CartState {
  final List<CartItem> items;
  final List<CartDeal> deals;
  final String customerName;
  final String orderType; // "dine-in", "takeaway", "delivery"
  final String? tableNumber;
  final String? deliveryAddress;
  final String? customerPhone;
  final DiscountModel? appliedManagerDiscount;
  final double manualDiscount; // negative only
  final double amountReceived;
  final String? editingOrderDocId;
  final String? editingOrderStatus;
  final String? editingOrderHumanId;
  final bool editingOrderIsPaid;
  final String orderTaker;
  final String? specialInstructions; // Order level instructions

  CartState({
    this.items = const [],
    this.deals = const [],
    this.customerName = "",
    this.orderType = "dine-in",
    this.tableNumber,
    this.deliveryAddress,
    this.customerPhone,
    this.appliedManagerDiscount,
    this.manualDiscount = 0.0,
    this.amountReceived = 0.0,
    this.editingOrderDocId,
    this.editingOrderStatus,
    this.editingOrderHumanId,
    this.editingOrderIsPaid = false,
    this.orderTaker = "Customer",
    this.specialInstructions = "",
  });

  CartState copyWith({
    List<CartItem>? items,
    List<CartDeal>? deals,
    String? customerName,
    String? orderType,
    String? tableNumber,
    String? deliveryAddress,
    String? customerPhone,
    DiscountModel? appliedManagerDiscount,
    bool clearManagerDiscount = false,
    double? manualDiscount,
    double? amountReceived,
    String? editingOrderDocId,
    bool clearEditingOrder = false,
    String? editingOrderStatus,
    String? editingOrderHumanId,
    bool? editingOrderIsPaid,
    String? orderTaker,
    String? specialInstructions,
  }) {
    return CartState(
      items: items ?? this.items,
      deals: deals ?? this.deals,
      customerName: customerName ?? this.customerName,
      orderType: orderType ?? this.orderType,
      tableNumber: tableNumber ?? this.tableNumber,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      appliedManagerDiscount: clearManagerDiscount ? null : (appliedManagerDiscount ?? this.appliedManagerDiscount),
      manualDiscount: manualDiscount ?? this.manualDiscount,
      amountReceived: amountReceived ?? this.amountReceived,
      editingOrderDocId: clearEditingOrder ? null : (editingOrderDocId ?? this.editingOrderDocId),
      editingOrderStatus: clearEditingOrder ? null : (editingOrderStatus ?? this.editingOrderStatus),
      editingOrderHumanId: clearEditingOrder ? null : (editingOrderHumanId ?? this.editingOrderHumanId),
      editingOrderIsPaid: clearEditingOrder ? false : (editingOrderIsPaid ?? this.editingOrderIsPaid),
      orderTaker: orderTaker ?? this.orderTaker,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  double get itemsSubtotal {
    double sum = items.fold(0.0, (total, element) => total + element.totalPrice);
    double dealsSum = deals.fold(0.0, (total, element) => total + element.price);
    return sum + dealsSum;
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return CartState();
  }

  void addItem(MenuItemModel item, {MenuItemVariant? variant}) {
    final existingIdx = state.items.indexWhere(
      (i) => i.item.id == item.id && i.selectedVariant?.name == variant?.name,
    );
    if (existingIdx != -1) {
      final updatedList = List<CartItem>.from(state.items);
      final current = updatedList[existingIdx];
      if (current.quantity < 99) {
        updatedList[existingIdx] = current.copyWith(quantity: current.quantity + 1);
        state = state.copyWith(items: updatedList);
      }
    } else {
      state = state.copyWith(items: [...state.items, CartItem(item: item, selectedVariant: variant)]);
    }
  }

  void addManualItem(String name, double price) {
    final manualItem = MenuItemModel(
      id: "manual_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      price: price,
      categoryId: "manual",
      description: "Manually entered custom item",
      imageBase64: "",
      prepTime: 0,
      status: "active",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(items: [...state.items, CartItem(item: manualItem, quantity: 1)]);
  }

  void addDeal(DealModel deal) {
    state = state.copyWith(deals: [...state.deals, CartDeal(deal: deal)]);
  }

  void removeDeal(int index) {
    final list = List<CartDeal>.from(state.deals);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      state = state.copyWith(deals: list);
    }
  }

  void updateDealSpecialInstructions(int index, String instructions) {
    if (index >= 0 && index < state.deals.length) {
      final list = List<CartDeal>.from(state.deals);
      list[index] = list[index].copyWith(specialInstructions: instructions);
      state = state.copyWith(deals: list);
    }
  }

  void increaseQuantity(int index) {
    if (index >= 0 && index < state.items.length) {
      final list = List<CartItem>.from(state.items);
      if (list[index].quantity < 99) {
        list[index] = list[index].copyWith(quantity: list[index].quantity + 1);
        state = state.copyWith(items: list);
      }
    }
  }

  void decreaseQuantity(int index) {
    if (index >= 0 && index < state.items.length) {
      final list = List<CartItem>.from(state.items);
      final currentQty = list[index].quantity;
      if (currentQty > 1) {
        list[index] = list[index].copyWith(quantity: currentQty - 1);
        state = state.copyWith(items: list);
      } else {
        list.removeAt(index);
        state = state.copyWith(items: list);
      }
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < state.items.length) {
      final list = List<CartItem>.from(state.items);
      list.removeAt(index);
      state = state.copyWith(items: list);
    }
  }

  void updateSpecialInstructions(int index, String instructions) {
    if (index >= 0 && index < state.items.length) {
      final list = List<CartItem>.from(state.items);
      list[index] = list[index].copyWith(specialInstructions: instructions);
      state = state.copyWith(items: list);
    }
  }

  void updateCartSpecialInstructions(String instructions) {
    state = state.copyWith(specialInstructions: instructions);
  }

  void clearCart() {
    state = CartState();
  }

  void startEditing(OrderModel order, List<MenuItemModel> allMenuItems) {
    final List<CartItem> cartItems = [];
    for (var item in order.items) {
      MenuItemModel? menuItem;
      try {
        menuItem = allMenuItems.firstWhere((m) => m.id == item.menuItemId);
      } catch (_) {}
      
      MenuItemModel finalMenuItem;
      MenuItemVariant? selectedVariant;
      if (menuItem != null) {
        finalMenuItem = menuItem;
        if (item.variantName != null) {
          try {
            selectedVariant = menuItem.variants.firstWhere((v) => v.name == item.variantName);
          } catch (_) {}
        }
      } else {
        // Fallback MenuItemModel if not found in current menu list
        finalMenuItem = MenuItemModel(
          id: item.menuItemId,
          name: item.variantName != null && item.name.contains(" (")
              ? item.name.substring(0, item.name.lastIndexOf(" ("))
              : item.name,
          categoryId: '',
          description: '',
          price: item.unitPrice,
          imageBase64: '',
          prepTime: 10,
          status: 'active',
          variants: item.variantName != null
              ? [MenuItemVariant(name: item.variantName!, price: item.unitPrice)]
              : [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        if (item.variantName != null) {
          selectedVariant = finalMenuItem.variants.first;
        }
      }
      
      cartItems.add(CartItem(
        item: finalMenuItem,
        quantity: item.quantity,
        specialInstructions: item.specialInstructions,
        selectedVariant: selectedVariant,
      ));
    }

    final List<CartDeal> cartDeals = [];
    for (var d in order.deals) {
      cartDeals.add(CartDeal(
        deal: DealModel(
          id: d['dealId'] ?? '',
          name: d['name'] ?? '',
          price: double.tryParse(d['price']?.toString() ?? '0') ?? 0.0,
          itemIds: List<String>.from(d['itemIds'] ?? []),
          imageBase64: '',
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        specialInstructions: d['specialInstructions'],
      ));
    }

    DiscountModel? discount;
    if (order.managerDiscount > 0) {
      discount = DiscountModel(
        id: 'temp_disc',
        name: 'Applied Discount',
        type: 'fixed',
        value: order.managerDiscount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    state = CartState(
      items: cartItems,
      deals: cartDeals,
      customerName: order.customerName,
      orderType: order.orderType,
      tableNumber: order.tableNumber,
      deliveryAddress: order.deliveryAddress,
      customerPhone: order.customerPhone,
      appliedManagerDiscount: discount,
      manualDiscount: -order.manualDiscount,
      editingOrderDocId: order.id,
      editingOrderStatus: order.status,
      editingOrderHumanId: order.orderId,
      editingOrderIsPaid: order.isPaid,
      orderTaker: order.orderTaker ?? 'Customer',
      specialInstructions: order.specialInstructions ?? '',
    );
  }

  void updateCustomerDetails({
    required String name,
    required String type,
    String? table,
    String? address,
    String? phone,
    String? orderTaker,
  }) {
    state = state.copyWith(
      customerName: name,
      orderType: type,
      tableNumber: table,
      deliveryAddress: address,
      customerPhone: phone,
      orderTaker: orderTaker,
    );
  }

  void applyManagerDiscount(DiscountModel discount) {
    state = state.copyWith(appliedManagerDiscount: discount);
  }

  void removeManagerDiscount() {
    state = state.copyWith(clearManagerDiscount: true);
  }

  void applyManualDiscount(double value) {
    final negativeValue = value > 0 ? -value : value;
    state = state.copyWith(manualDiscount: negativeValue);
  }

  void updatePaymentDetails(double received) {
    state = state.copyWith(amountReceived: received);
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

// Stream of orders for the logged-in cashier - kept alive to avoid re-fetching on tab navigation
final cashierOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  ref.keepAlive();
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(orderRepositoryProvider).watchOrdersByCashier(user.uid);
});

// Cashier order placement action notifier
class CashierActionNotifier extends Notifier<AsyncValue<String>> {
  @override
  AsyncValue<String> build() {
    return const AsyncValue.data('');
  }

  Future<void> submitOrder(SettingsModel settings) async {
    state = const AsyncValue.loading();
    try {
      final cart = ref.read(cartProvider);
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception("User not authenticated.");

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
      double change = 0.0;

      final List<OrderItemModel> items = cart.items.map((i) {
        return OrderItemModel(
          menuItemId: i.item.id,
          name: i.selectedVariant != null ? "${i.item.name} (${i.selectedVariant!.name})" : i.item.name,
          quantity: i.quantity,
          unitPrice: i.selectedVariant?.price ?? i.item.price,
          totalPrice: i.totalPrice,
          specialInstructions: i.specialInstructions,
          variantName: i.selectedVariant?.name,
        );
      }).toList();

      final List<dynamic> deals = cart.deals.map((d) {
        return {
          'dealId': d.deal.id,
          'name': d.deal.name,
          'price': d.deal.price,
          'itemIds': d.deal.itemIds,
          'specialInstructions': d.specialInstructions,
        };
      }).toList();

      String orderDocId;
      if (cart.editingOrderDocId != null) {
        final existing = await ref.read(orderRepositoryProvider).getOrderById(cart.editingOrderDocId!);
        if (existing == null) throw Exception("Existing order not found.");

        List<OrderItemModel> finalItems = items;
        List<dynamic> finalDeals = deals;
        double finalSubtotal = subtotal;
        double finalDiscountAmount = discountAmount;
        double finalManualDiscount = manualD;
        double finalManagerDiscount = managerD;
        double finalTax = tax;
        double finalDeliveryCharges = delivery;
        double finalGrandTotal = grandTotal;
        
        String finalCustomerName = cart.customerName;
        String finalOrderType = cart.orderType;
        String? finalTableNumber = cart.tableNumber;
        String? finalDeliveryAddress = cart.deliveryAddress;
        String? finalCustomerPhone = cart.customerPhone;

        if (existing.status == "In Preparation" || existing.status == "Ready") {
          // Cashier is only allowed to edit customer details. Items, deals, discounts remain same as existing order!
          finalItems = existing.items;
          finalDeals = existing.deals;
          finalSubtotal = existing.subtotal;
          finalDiscountAmount = existing.discountAmount;
          finalManualDiscount = existing.manualDiscount;
          finalManagerDiscount = existing.managerDiscount;
          finalTax = existing.tax;
          finalDeliveryCharges = existing.deliveryCharges;
          finalGrandTotal = existing.grandTotal;
        } else if (existing.status == "Handover") {
          // Cashier is only allowed to edit discounts. Items, deals, and customer details remain same as existing order!
          finalItems = existing.items;
          finalDeals = existing.deals;
          finalSubtotal = existing.subtotal;
          
          finalCustomerName = existing.customerName;
          finalOrderType = existing.orderType;
          finalTableNumber = existing.tableNumber;
          finalDeliveryAddress = existing.deliveryAddress;
          finalCustomerPhone = existing.customerPhone;
          
          // Re-calculate tax & total with the updated discount
          finalManualDiscount = manualD;
          finalManagerDiscount = managerD;
          finalDiscountAmount = finalManagerDiscount + finalManualDiscount;
          
          double baseForTax = finalSubtotal - finalDiscountAmount;
          if (baseForTax < 0) baseForTax = 0;
          finalTax = baseForTax * (settings.taxRate / 100);
          finalDeliveryCharges = finalOrderType == "delivery" ? settings.deliveryCharges : 0.0;
          finalGrandTotal = baseForTax + finalTax + finalDeliveryCharges;
        }

        final updatedOrder = OrderModel(
          id: existing.id,
          orderId: existing.orderId,
          tokenId: existing.tokenId,
          cashierId: existing.cashierId,
          cashierName: existing.cashierName,
          customerName: finalCustomerName,
          orderType: finalOrderType,
          tableNumber: finalTableNumber,
          deliveryAddress: finalDeliveryAddress,
          customerPhone: finalCustomerPhone,
          items: finalItems,
          deals: finalDeals,
          subtotal: finalSubtotal,
          discountAmount: finalDiscountAmount,
          manualDiscount: finalManualDiscount,
          managerDiscount: finalManagerDiscount,
          tax: finalTax,
          deliveryCharges: finalDeliveryCharges,
          grandTotal: finalGrandTotal,
          amountReceived: finalGrandTotal,
          change: 0.0,
          status: existing.status,
          statusHistory: existing.statusHistory,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          orderTaker: cart.orderTaker,
          riderName: existing.riderName,
          isPaid: existing.isPaid,
          specialInstructions: cart.specialInstructions,
        );

        await ref.read(orderRepositoryProvider).updateOrderDetails(updatedOrder);
        orderDocId = existing.id;
      } else {
        final newOrder = OrderModel(
          id: "",
          orderId: "",
          cashierId: user.uid,
          cashierName: user.name,
          customerName: cart.customerName,
          orderType: cart.orderType,
          tableNumber: cart.tableNumber,
          deliveryAddress: cart.deliveryAddress,
          customerPhone: cart.customerPhone,
          items: items,
          deals: deals,
          subtotal: subtotal,
          discountAmount: discountAmount,
          manualDiscount: manualD,
          managerDiscount: managerD,
          tax: tax,
          deliveryCharges: delivery,
          grandTotal: grandTotal,
          amountReceived: grandTotal,
          change: 0.0,
          status: "Pending",
          statusHistory: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          orderTaker: cart.orderTaker,
          specialInstructions: cart.specialInstructions,
        );
        orderDocId = await ref.read(orderRepositoryProvider).placeOrder(newOrder);
      }
      ref.read(cartProvider.notifier).clearCart();
      if (ref.mounted) {
        state = AsyncValue.data(orderDocId);
      }
    } catch (e, st) {
      if (ref.mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final cashierActionProvider = NotifierProvider<CashierActionNotifier, AsyncValue<String>>(() {
  return CashierActionNotifier();
});

// Direct single-order fetch by document ID — watches the order in real time so status updates immediately
final singleOrderProvider = StreamProvider.family<OrderModel?, String>((ref, docId) {
  if (docId.isEmpty) return Stream.value(null);
  return ref.watch(orderRepositoryProvider).watchOrderById(docId);
});
