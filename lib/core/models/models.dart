import 'dart:convert';

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now().toLocal();
  if (value is DateTime) return value.toLocal();
  // Safely handle Firestore Timestamp without tight coupling
  try {
    if (value.runtimeType.toString().contains('Timestamp') || 
        value.toString().contains('Timestamp')) {
      return ((value as dynamic).toDate() as DateTime).toLocal();
    }
  } catch (_) {}
  try {
    if (value is String) return DateTime.parse(value).toLocal();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  } catch (_) {}
  return DateTime.now().toLocal();
}
DateTime parseDateTime(dynamic value) => _parseDateTime(value);

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

// 1. UserModel
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // "manager", "cashier", "expediter"
  final String status; // "active", "disabled"
  final bool forcePasswordChange;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.forcePasswordChange,
    required this.createdAt,
    required this.updatedAt,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? status,
    bool? forcePasswordChange,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'forcePasswordChange': forcePasswordChange,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'cashier',
      status: map['status'] ?? 'active',
      forcePasswordChange: map['forcePasswordChange'] ?? false,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }
}

// 2. CategoryModel
class CategoryModel {
  final String id;
  final String name;
  final String imageBase64;
  final String status; // "active", "disabled"
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.imageBase64,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? imageBase64,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageBase64: imageBase64 ?? this.imageBase64,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageBase64': imageBase64,
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String docId) {
    return CategoryModel(
      id: docId,
      name: map['name'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }
}

// MenuItemVariant definition for menu item size/volume options
class MenuItemVariant {
  final String name;
  final double? price;

  MenuItemVariant({required this.name, this.price});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory MenuItemVariant.fromMap(Map<String, dynamic> map) {
    return MenuItemVariant(
      name: map['name'] ?? '',
      price: (map['price'] == null) ? null : ((map['price'] is num) ? (map['price'] as num).toDouble() : double.tryParse(map['price'].toString())),
    );
  }
}

// 3. MenuItemModel
class MenuItemModel {
  final String id;
  final String name;
  final String categoryId;
  final String description;
  final double price;
  final String imageBase64;
  final int prepTime; // minutes
  final String status; // "active", "disabled"
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MenuItemVariant> variants;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.description,
    required this.price,
    required this.imageBase64,
    required this.prepTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.variants = const [],
  });

  MenuItemModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? description,
    double? price,
    String? imageBase64,
    int? prepTime,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MenuItemVariant>? variants,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      price: price ?? this.price,
      imageBase64: imageBase64 ?? this.imageBase64,
      prepTime: prepTime ?? this.prepTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      variants: variants ?? this.variants,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'description': description,
      'price': price,
      'imageBase64': imageBase64,
      'prepTime': prepTime,
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'variants': variants.map((v) => v.toMap()).toList(),
    };
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map, String docId) {
    return MenuItemModel(
      id: docId,
      name: map['name'] ?? '',
      categoryId: map['categoryId'] ?? '',
      description: map['description'] ?? '',
      price: _parseDouble(map['price']),
      imageBase64: map['imageBase64'] ?? '',
      prepTime: _parseInt(map['prepTime']),
      status: map['status'] ?? 'active',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      variants: (map['variants'] as List?)
              ?.map((v) => MenuItemVariant.fromMap(Map<String, dynamic>.from(v)))
              .toList() ??
          const [],
    );
  }
}

// 4. DealModel
class DealModel {
  final String id;
  final String name;
  final double price;
  final List<String> itemIds;
  final String imageBase64;
  final String status; // "active", "disabled"
  final DateTime createdAt;
  final DateTime updatedAt;

  DealModel({
    required this.id,
    required this.name,
    required this.price,
    required this.itemIds,
    required this.imageBase64,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  DealModel copyWith({
    String? id,
    String? name,
    double? price,
    List<String>? itemIds,
    String? imageBase64,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DealModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      itemIds: itemIds ?? this.itemIds,
      imageBase64: imageBase64 ?? this.imageBase64,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'itemIds': itemIds,
      'imageBase64': imageBase64,
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory DealModel.fromMap(Map<String, dynamic> map, String docId) {
    return DealModel(
      id: docId,
      name: map['name'] ?? '',
      price: _parseDouble(map['price']),
      itemIds: List<String>.from(map['itemIds'] ?? []),
      imageBase64: map['imageBase64'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }
}

// 5. DiscountModel
class DiscountModel {
  final String id;
  final String name;
  final String type; // "percentage", "fixed"
  final double value;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiscountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  DiscountModel copyWith({
    String? id,
    String? name,
    String? type,
    double? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiscountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory DiscountModel.fromMap(Map<String, dynamic> map, String docId) {
    return DiscountModel(
      id: docId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'percentage',
      value: _parseDouble(map['value']),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }
}

// 6. OrderItemModel
class OrderItemModel {
  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? specialInstructions;
  final String? variantName;

  OrderItemModel({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.specialInstructions,
    this.variantName,
  });

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'specialInstructions': specialInstructions,
      'variantName': variantName,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      quantity: _parseInt(map['quantity']),
      unitPrice: _parseDouble(map['unitPrice']),
      totalPrice: _parseDouble(map['totalPrice']),
      specialInstructions: map['specialInstructions'],
      variantName: map['variantName'],
    );
  }
}

// 7. OrderModel
class OrderModel {
  final String id;
  final String orderId; // 6-digit zero-padded: e.g. "000042"
  final String? tokenId; // 3-digit zero-padded daily token
  final String cashierId;
  final String cashierName;
  final String customerName;
  final String orderType; // "dine-in", "takeaway", "delivery"
  final String? tableNumber;
  final String? deliveryAddress;
  final String? customerPhone;
  final List<OrderItemModel> items;
  final List<dynamic> deals; // detailed JSON/List representation of deals if any
  final double subtotal;
  final double discountAmount;
  final double manualDiscount;
  final double managerDiscount;
  final double tax;
  final double deliveryCharges;
  final double grandTotal;
  final double amountReceived;
  final double change;
  final String status; // "Pending", "In Preparation", "Ready", "Completed", "Cancelled"
  final List<Map<String, dynamic>> statusHistory;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPaid;
  final String? orderTaker;
  final String? riderName;

  OrderModel({
    required this.id,
    required this.orderId,
    this.tokenId,
    required this.cashierId,
    required this.cashierName,
    required this.customerName,
    required this.orderType,
    this.tableNumber,
    this.deliveryAddress,
    this.customerPhone,
    required this.items,
    required this.deals,
    required this.subtotal,
    required this.discountAmount,
    required this.manualDiscount,
    required this.managerDiscount,
    required this.tax,
    required this.deliveryCharges,
    required this.grandTotal,
    required this.amountReceived,
    required this.change,
    required this.status,
    required this.statusHistory,
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledBy,
    required this.createdAt,
    required this.updatedAt,
    this.isPaid = false,
    this.orderTaker = "Customer",
    this.riderName,
  });

  OrderModel copyWith({
    String? id,
    String? orderId,
    String? tokenId,
    String? cashierId,
    String? cashierName,
    String? customerName,
    String? orderType,
    String? tableNumber,
    String? deliveryAddress,
    String? customerPhone,
    List<OrderItemModel>? items,
    List<dynamic>? deals,
    double? subtotal,
    double? discountAmount,
    double? manualDiscount,
    double? managerDiscount,
    double? tax,
    double? deliveryCharges,
    double? grandTotal,
    double? amountReceived,
    double? change,
    String? status,
    List<Map<String, dynamic>>? statusHistory,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? cancelledBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPaid,
    String? orderTaker,
    String? riderName,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      tokenId: tokenId ?? this.tokenId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      customerName: customerName ?? this.customerName,
      orderType: orderType ?? this.orderType,
      tableNumber: tableNumber ?? this.tableNumber,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      deals: deals ?? this.deals,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      managerDiscount: managerDiscount ?? this.managerDiscount,
      tax: tax ?? this.tax,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      grandTotal: grandTotal ?? this.grandTotal,
      amountReceived: amountReceived ?? this.amountReceived,
      change: change ?? this.change,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPaid: isPaid ?? this.isPaid,
      orderTaker: orderTaker ?? this.orderTaker,
      riderName: riderName ?? this.riderName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'tokenId': tokenId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'customerName': customerName,
      'orderType': orderType,
      'tableNumber': tableNumber,
      'deliveryAddress': deliveryAddress,
      'customerPhone': customerPhone,
      'items': items.map((i) => i.toMap()).toList(),
      'deals': deals,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'manualDiscount': manualDiscount,
      'managerDiscount': managerDiscount,
      'tax': tax,
      'deliveryCharges': deliveryCharges,
      'grandTotal': grandTotal,
      'amountReceived': amountReceived,
      'change': change,
      'status': status,
      'statusHistory': statusHistory.map((h) => {
        'status': h['status'],
        'timestamp': _parseDateTime(h['timestamp']).toUtc().toIso8601String(),
        'updatedBy': h['updatedBy']
      }).toList(),
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt?.toUtc().toIso8601String(),
      'cancelledBy': cancelledBy,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isPaid': isPaid,
      'orderTaker': orderTaker,
      'riderName': riderName,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    return OrderModel(
      id: docId,
      orderId: map['orderId'] ?? '',
      tokenId: map['tokenId'],
      cashierId: map['cashierId'] ?? '',
      cashierName: map['cashierName'] ?? '',
      customerName: map['customerName'] ?? '',
      orderType: map['orderType'] ?? 'dine-in',
      tableNumber: map['tableNumber'],
      deliveryAddress: map['deliveryAddress'],
      customerPhone: map['customerPhone'],
      items: (map['items'] as List? ?? []).map((i) => OrderItemModel.fromMap(Map<String, dynamic>.from(i))).toList(),
      deals: List<dynamic>.from(map['deals'] ?? []),
      subtotal: _parseDouble(map['subtotal']),
      discountAmount: _parseDouble(map['discountAmount']),
      manualDiscount: _parseDouble(map['manualDiscount']),
      managerDiscount: _parseDouble(map['managerDiscount']),
      tax: _parseDouble(map['tax']),
      deliveryCharges: _parseDouble(map['deliveryCharges']),
      grandTotal: _parseDouble(map['grandTotal']),
      amountReceived: _parseDouble(map['amountReceived']),
      change: _parseDouble(map['change']),
      status: map['status'] ?? 'Pending',
      statusHistory: (map['statusHistory'] as List? ?? []).map((h) {
        final item = Map<String, dynamic>.from(h);
        return {
          'status': item['status'] ?? 'Pending',
          'timestamp': _parseDateTime(item['timestamp']),
          'updatedBy': item['updatedBy'] ?? '',
        };
      }).toList(),
      cancellationReason: map['cancellationReason'],
      cancelledAt: map['cancelledAt'] != null ? _parseDateTime(map['cancelledAt']) : null,
      cancelledBy: map['cancelledBy'],
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      isPaid: map['isPaid'] ?? false,
      orderTaker: map['orderTaker'] ?? 'Customer',
      riderName: map['riderName'],
    );
  }
}

// 8. ActivityLogModel
class ActivityLogModel {
  final String id;
  final String orderId;
  final String previousStatus;
  final String newStatus;
  final String expediterId;
  final String expediterName;
  final DateTime timestamp;

  ActivityLogModel({
    required this.id,
    required this.orderId,
    required this.previousStatus,
    required this.newStatus,
    required this.expediterId,
    required this.expediterName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'previousStatus': previousStatus,
      'newStatus': newStatus,
      'expediterId': expediterId,
      'expediterName': expediterName,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory ActivityLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityLogModel(
      id: docId,
      orderId: map['orderId'] ?? '',
      previousStatus: map['previousStatus'] ?? '',
      newStatus: map['newStatus'] ?? '',
      expediterId: map['expediterId'] ?? '',
      expediterName: map['expediterName'] ?? '',
      timestamp: _parseDateTime(map['timestamp']),
    );
  }
}

// 9. SettingsModel
class SettingsModel {
  final String id;
  final String phoneNumber;
  final double deliveryCharges;
  final double taxRate;
  final DateTime updatedAt;
  final String cashierReportPassword;

  SettingsModel({
    required this.id,
    required this.phoneNumber,
    required this.deliveryCharges,
    required this.taxRate,
    required this.updatedAt,
    this.cashierReportPassword = '',
  });

  SettingsModel copyWith({
    String? id,
    String? phoneNumber,
    double? deliveryCharges,
    double? taxRate,
    DateTime? updatedAt,
    String? cashierReportPassword,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      taxRate: taxRate ?? this.taxRate,
      updatedAt: updatedAt ?? this.updatedAt,
      cashierReportPassword: cashierReportPassword ?? this.cashierReportPassword,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'deliveryCharges': deliveryCharges,
      'taxRate': taxRate,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'cashierReportPassword': cashierReportPassword,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map, String docId) {
    return SettingsModel(
      id: docId,
      phoneNumber: map['phoneNumber'] ?? '03001234567',
      deliveryCharges: _parseDouble(map['deliveryCharges']),
      taxRate: _parseDouble(map['taxRate']),
      updatedAt: _parseDateTime(map['updatedAt']),
      cashierReportPassword: map['cashierReportPassword'] ?? '',
    );
  }
}

// 10. DailyClosingModel
class DailyClosingModel {
  final String id; // format: "YYYY-MM-DD"
  final double cashAmount;
  final double onlineAmount;
  final double cardAmount;
  final int totalPunchOrders;
  final int cancelledOrders;
  final int totalConfirmedOrders;
  final double totalTodayRevenue;
  final String closedBy;
  final String closedByName;
  final DateTime createdAt;
  final bool isReleased;

  DailyClosingModel({
    required this.id,
    required this.cashAmount,
    required this.onlineAmount,
    required this.cardAmount,
    required this.totalPunchOrders,
    required this.cancelledOrders,
    required this.totalConfirmedOrders,
    required this.totalTodayRevenue,
    required this.closedBy,
    required this.closedByName,
    required this.createdAt,
    required this.isReleased,
  });

  DailyClosingModel copyWith({
    String? id,
    double? cashAmount,
    double? onlineAmount,
    double? cardAmount,
    int? totalPunchOrders,
    int? cancelledOrders,
    int? totalConfirmedOrders,
    double? totalTodayRevenue,
    String? closedBy,
    String? closedByName,
    DateTime? createdAt,
    bool? isReleased,
  }) {
    return DailyClosingModel(
      id: id ?? this.id,
      cashAmount: cashAmount ?? this.cashAmount,
      onlineAmount: onlineAmount ?? this.onlineAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      totalPunchOrders: totalPunchOrders ?? this.totalPunchOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      totalConfirmedOrders: totalConfirmedOrders ?? this.totalConfirmedOrders,
      totalTodayRevenue: totalTodayRevenue ?? this.totalTodayRevenue,
      closedBy: closedBy ?? this.closedBy,
      closedByName: closedByName ?? this.closedByName,
      createdAt: createdAt ?? this.createdAt,
      isReleased: isReleased ?? this.isReleased,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'cardAmount': cardAmount,
      'totalPunchOrders': totalPunchOrders,
      'cancelledOrders': cancelledOrders,
      'totalConfirmedOrders': totalConfirmedOrders,
      'totalTodayRevenue': totalTodayRevenue,
      'closedBy': closedBy,
      'closedByName': closedByName,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isReleased': isReleased,
    };
  }

  factory DailyClosingModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyClosingModel(
      id: docId,
      cashAmount: _parseDouble(map['cashAmount']),
      onlineAmount: _parseDouble(map['onlineAmount']),
      cardAmount: _parseDouble(map['cardAmount']),
      totalPunchOrders: map['totalPunchOrders'] ?? 0,
      cancelledOrders: map['cancelledOrders'] ?? 0,
      totalConfirmedOrders: map['totalConfirmedOrders'] ?? 0,
      totalTodayRevenue: _parseDouble(map['totalTodayRevenue']),
      closedBy: map['closedBy'] ?? '',
      closedByName: map['closedByName'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      isReleased: map['isReleased'] ?? false,
    );
  }
}

String getDealItemsDescription(List<dynamic> itemIds, List<MenuItemModel> allMenuItems) {
  if (itemIds.isEmpty) return "Promo Package Only";

  final Map<String, int> counts = {};
  for (final id in itemIds) {
    if (id is String) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }

  final List<String> parts = [];
  for (final entry in counts.entries) {
    final key = entry.key;
    final qty = entry.value;

    String displayName = key;
    if (key.contains("::")) {
      final split = key.split("::");
      final mId = split[0];
      final varName = split[1];
      try {
        final match = allMenuItems.firstWhere((m) => m.id == mId);
        displayName = "${match.name} ($varName)";
      } catch (_) {
        displayName = varName;
      }
    } else {
      try {
        final match = allMenuItems.firstWhere((m) => m.id == key);
        displayName = match.name;
      } catch (_) {
        displayName = key;
      }
    }
    parts.add("$displayName x$qty");
  }
  return parts.join(", ");
}

// 10. WaiterModel
class WaiterModel {
  final String id;
  final String name;
  final String status; // "active", "inactive"
  final DateTime createdAt;

  WaiterModel({
    required this.id,
    required this.name,
    this.status = "active",
    required this.createdAt,
  });

  WaiterModel copyWith({
    String? id,
    String? name,
    String? status,
    DateTime? createdAt,
  }) {
    return WaiterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory WaiterModel.fromMap(Map<String, dynamic> map, String docId) {
    return WaiterModel(
      id: docId,
      name: map['name'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }
}

// 11. RiderModel
class RiderModel {
  final String id;
  final String name;
  final String phone;
  final String status; // "active", "inactive"
  final DateTime createdAt;

  RiderModel({
    required this.id,
    required this.name,
    required this.phone,
    this.status = "active",
    required this.createdAt,
  });

  RiderModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? status,
    DateTime? createdAt,
  }) {
    return RiderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory RiderModel.fromMap(Map<String, dynamic> map, String docId) {
    return RiderModel(
      id: docId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }
}
