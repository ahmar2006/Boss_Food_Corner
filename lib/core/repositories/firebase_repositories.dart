import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'repositories.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<UserModel?> login(String email, String password) async {
    final trimmedEmail = email.trim();
    fb_auth.UserCredential? credential;
    bool isStaffPasswordAuth = false;

    // 1. Try unified staff password first
    try {
      final staffAuthPassword = "staffpassword123";
      credential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: staffAuthPassword,
      );
      isStaffPasswordAuth = true;
    } catch (_) {
      // Fall through to try direct password authentication
    }

    // 2. Try direct password authentication if staff auth failed
    if (credential == null) {
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: trimmedEmail,
          password: password,
        );
        isStaffPasswordAuth = false;
      } catch (e) {
        throw Exception("Invalid email or password.");
      }
    }

    if (credential.user == null) {
      throw Exception("Invalid email or password.");
    }

    // 3. Fetch user record from Firestore
    final doc = await _firestore.collection('users').doc(credential.user!.uid).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw Exception("User record not found in database.");
    }

    final user = UserModel.fromMap(doc.data()!, doc.id);
    if (user.status == "disabled") {
      await _auth.signOut();
      throw Exception("Your account has been disabled. Please contact your manager.");
    }

    // 4. Validate credentials based on role
    if (user.role == "manager") {
      if (isStaffPasswordAuth) {
        // Manager authenticated with staffpassword123 — they were likely an employee
        // whose role was changed to manager in Firestore.
        // Verify entered password against Firestore stored password.
        final storedPassword = doc.data()!['password'] ?? '';
        if (storedPassword.isNotEmpty && storedPassword != password) {
          await _auth.signOut();
          throw Exception("Invalid email or password.");
        }
      }
      // Manager authenticated with their direct password — allow through
      return user;
    } else {
      // Employee flow
      final storedPassword = doc.data()!['password'] ?? '';
      
      if (isStaffPasswordAuth) {
        // Authenticated with staffpassword123, now verify against Firestore personal password
        if (storedPassword != password) {
          await _auth.signOut();
          throw Exception("Invalid email or password.");
        }
      } else {
        // Authenticated with direct password (legacy employee or newly reset).
        // Check if the entered password matches Firestore just to be sure
        if (storedPassword != password) {
          await _auth.signOut();
          throw Exception("Invalid email or password.");
        }
        // Auto-migrate this legacy employee to use the unified staffpassword123
        try {
          await _auth.currentUser!.updatePassword("staffpassword123");
        } catch (e) {
          // If update password fails, log it, but don't block the user's active session.
        }
      }
      return user;
    }
  }

  @override
  Future<UserModel?> registerManager(String name, String email, String password, String phone) async {
    // Check if manager already exists
    final hasExistingManager = await hasManager();
    if (hasExistingManager) {
      throw Exception("A manager account already exists in the system.");
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user == null) {
      throw Exception("User creation failed.");
    }

    final newManager = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email.trim(),
      phone: phone,
      role: "manager",
      status: "active",
      forcePasswordChange: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(credential.user!.uid).set(newManager.toMap());
    return newManager;
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    // Re-authenticate user
    final email = user.email!;
    final cred = fb_auth.EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(cred);

    // Update password
    await user.updatePassword(newPassword);

    // Update firestore status
    await _firestore.collection('users').doc(user.uid).update({
      'forcePasswordChange': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> forgotPassword(String email) async {
    // Query users collection to check role, matching security rules filter
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .where('role', isEqualTo: 'manager')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("No manager account registered with this email.");
    }

    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  @override
  Stream<UserModel?> watchCurrentUser() {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) return null;
      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Future<bool> hasManager() async {
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }
}

class FirebaseEmployeeRepository implements EmployeeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<UserModel>> watchEmployees() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .where((u) => u.role != "manager") // Don't list manager in employees list
          .toList();
    });
  }

  @override
  Future<void> addEmployee(String name, String email, String password, String phone, String role) async {
    // Check email uniqueness in Firestore first
    final emailQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (emailQuery.docs.isNotEmpty) {
      throw Exception("Email address is already in use by another employee.");
    }

    // Creating Firebase Auth for another user requires secondary auth instance
    // or Cloud Function, but to remain serverless without logging out the manager,
    // we initialize a temporary Firebase App to register:
    final tempAppName = 'temp_register_${DateTime.now().millisecondsSinceEpoch}';
    final tempApp = await Firebase.initializeApp(
      name: tempAppName,
      options: Firebase.app().options,
    );
    final tempAuth = fb_auth.FirebaseAuth.instanceFor(app: tempApp);

    try {
      final staffAuthPassword = "staffpassword123";
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: staffAuthPassword,
      );

      if (credential.user == null) {
        throw Exception("Employee creation failed.");
      }

      final newEmployee = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email.trim(),
        phone: phone,
        role: role,
        status: "active",
        forcePasswordChange: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = newEmployee.toMap();
      map['password'] = password; // Store actual personal password in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set(map);

      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }
  }

  @override
  Future<void> editEmployee(UserModel employee) async {
    await _firestore.collection('users').doc(employee.uid).update({
      'name': employee.name,
      'phone': employee.phone,
      'role': employee.role,
      'status': employee.status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> toggleEmployeeStatus(String uid, String currentStatus) async {
    final newStatus = currentStatus == "active" ? "disabled" : "active";
    await _firestore.collection('users').doc(uid).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> resetEmployeePassword(String uid, String newPassword) async {
    // 1. Fetch current employee email and password from Firestore to handle legacy migration
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final email = doc.data()?['email'] ?? '';
      final oldPassword = doc.data()?['password'] ?? '';
      
      if (email.isNotEmpty && oldPassword.isNotEmpty) {
        final tempAppName = 'temp_reset_${DateTime.now().millisecondsSinceEpoch}';
        final tempApp = await Firebase.initializeApp(
          name: tempAppName,
          options: Firebase.app().options,
        );
        final tempAuth = fb_auth.FirebaseAuth.instanceFor(app: tempApp);

        try {
          // If they were registered under their personal password, migrate them to staffpassword123
          try {
            await tempAuth.signInWithEmailAndPassword(email: email, password: oldPassword);
            await tempAuth.currentUser?.updatePassword('staffpassword123');
          } catch (_) {
            // Already migrated or wrong old password, which is fine
          }
          await tempAuth.signOut();
        } finally {
          await tempApp.delete();
        }
      }
    }

    // 2. Update Firestore password
    await _firestore.collection('users').doc(uid).update({
      'password': newPassword,
      'forcePasswordChange': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteEmployee(UserModel employee) async {
    // 1. Try to delete the Firebase Auth user first to keep Auth clean
    final tempAppName = 'temp_delete_${DateTime.now().millisecondsSinceEpoch}';
    final tempApp = await Firebase.initializeApp(
      name: tempAppName,
      options: Firebase.app().options,
    );
    final tempAuth = fb_auth.FirebaseAuth.instanceFor(app: tempApp);

    try {
      final doc = await _firestore.collection('users').doc(employee.uid).get();
      String empPassword = 'staffpassword123';
      if (doc.exists) {
        empPassword = doc.data()?['password'] ?? 'staffpassword123';
      }

      // Try signing in with the stored password to delete
      try {
        await tempAuth.signInWithEmailAndPassword(email: employee.email, password: empPassword);
        await tempAuth.currentUser?.delete();
      } catch (_) {
        // Fallback: try signing in with the constant staff password
        try {
          await tempAuth.signInWithEmailAndPassword(email: employee.email, password: 'staffpassword123');
          await tempAuth.currentUser?.delete();
        } catch (_) {
          // User might not exist in Firebase Auth
        }
      }
      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }

    // 2. Delete Firestore document
    await _firestore.collection('users').doc(employee.uid).delete();
  }

  @override
  Future<int> getEmployeeOrderCount(String uid) async {
    final query = await _firestore
        .collection('orders')
        .where('cashierId', isEqualTo: uid)
        .get();
    return query.docs.length;
  }
}

class FirebaseCategoryRepository implements CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<CategoryModel>> watchCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CategoryModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> addCategory(String name, String imageBase64, String status) async {
    // Unique check
    final query = await _firestore
        .collection('categories')
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception("Category name already exists.");
    }

    final docRef = _firestore.collection('categories').doc();
    final newCat = CategoryModel(
      id: docRef.id,
      name: name.trim(),
      imageBase64: imageBase64,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newCat.toMap());
  }

  @override
  Future<void> editCategory(CategoryModel category) async {
    await _firestore.collection('categories').doc(category.id).update(category.toMap());
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }

  @override
  Future<int> getCategoryItemCount(String id) async {
    final query = await _firestore
        .collection('menu_items')
        .where('categoryId', isEqualTo: id)
        .get();
    return query.docs.length;
  }
}

class FirebaseMenuRepository implements MenuRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<MenuItemModel>> watchMenuItems() {
    return _firestore.collection('menu_items').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => MenuItemModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> addMenuItem(MenuItemModel item) async {
    final query = await _firestore
        .collection('menu_items')
        .where('name', isEqualTo: item.name.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception("Menu item name already exists.");
    }

    final docRef = _firestore.collection('menu_items').doc();
    final newItem = item.copyWith(id: docRef.id, createdAt: DateTime.now(), updatedAt: DateTime.now());
    await docRef.set(newItem.toMap());
  }

  @override
  Future<void> editMenuItem(MenuItemModel item) async {
    await _firestore.collection('menu_items').doc(item.id).update(item.toMap());
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    await _firestore.collection('menu_items').doc(id).delete();
  }

  @override
  Future<int> getMenuItemOrderCount(String id) async {
    // Requires a collectionGroup query or iterating past orders.
    // For free-tier simplicity, check past 100 orders:
    final query = await _firestore.collection('orders').limit(100).get();
    int count = 0;
    for (var doc in query.docs) {
      final order = OrderModel.fromMap(doc.data(), doc.id);
      for (var item in order.items) {
        if (item.menuItemId == id) count++;
      }
    }
    return count;
  }
}

class FirebaseDealRepository implements DealRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<DealModel>> watchDeals() {
    return _firestore.collection('deals').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DealModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> addDeal(DealModel deal) async {
    final query = await _firestore
        .collection('deals')
        .where('name', isEqualTo: deal.name.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception("Deal name already exists.");
    }

    final docRef = _firestore.collection('deals').doc();
    final newDeal = deal.copyWith(id: docRef.id, createdAt: DateTime.now(), updatedAt: DateTime.now());
    await docRef.set(newDeal.toMap());
  }

  @override
  Future<void> editDeal(DealModel deal) async {
    await _firestore.collection('deals').doc(deal.id).update(deal.toMap());
  }

  @override
  Future<void> deleteDeal(String id) async {
    await _firestore.collection('deals').doc(id).delete();
  }
}

class FirebaseDiscountRepository implements DiscountRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<DiscountModel>> watchDiscounts() {
    return _firestore.collection('discounts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DiscountModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> addDiscount(DiscountModel discount) async {
    final query = await _firestore
        .collection('discounts')
        .where('name', isEqualTo: discount.name.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception("Discount name already exists.");
    }

    final docRef = _firestore.collection('discounts').doc();
    final newDisc = discount.copyWith(id: docRef.id, createdAt: DateTime.now(), updatedAt: DateTime.now());
    await docRef.set(newDisc.toMap());
  }

  @override
  Future<void> editDiscount(DiscountModel discount) async {
    await _firestore.collection('discounts').doc(discount.id).update(discount.toMap());
  }

  @override
  Future<void> deleteDiscount(String id) async {
    await _firestore.collection('discounts').doc(id).delete();
  }
}

class FirebaseOrderRepository implements OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<OrderModel>> watchAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Stream<List<OrderModel>> watchOrdersByCashier(String cashierId) {
    return _firestore
        .collection('orders')
        .where('cashierId', isEqualTo: cashierId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<OrderModel>> watchActiveOrders() {
    return _firestore
        .collection('orders')
        .where('status', whereNotIn: ['Completed', 'Cancelled', 'Handover'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Stream<OrderModel?> watchOrderById(String docId) {
    return _firestore
        .collection('orders')
        .doc(docId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromMap(doc.data()!, doc.id) : null);
  }

  @override
  Future<OrderModel?> getOrderById(String docId) async {
    final doc = await _firestore.collection('orders').doc(docId).get();
    if (!doc.exists) return null;
    return OrderModel.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<OrderModel?> getOrderByHumanId(String orderId) async {
    final query = await _firestore
        .collection('orders')
        .where('orderId', isEqualTo: orderId.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return OrderModel.fromMap(query.docs.first.data(), query.docs.first.id);
  }

  @override
  Future<String> placeOrder(OrderModel order) async {
    final counterRef = _firestore.collection('counters').doc('orderIdCounter');
    final tokenCounterRef = _firestore.collection('counters').doc('tokenIdCounter');
    final docRef = _firestore.collection('orders').doc();

    try {
      // Fetch both counters in parallel for speed
      final results = await Future.wait([
        counterRef.get(),
        tokenCounterRef.get(),
      ]);

      final counterSnapshot = results[0];
      final tokenSnapshot = results[1];

      int lastId = 0;
      if (counterSnapshot.exists) {
        lastId = counterSnapshot.data()?['lastUsedId'] ?? 0;
      }
      final nextId = lastId + 1;

      int lastToken = 0;
      String lastDate = "";
      if (tokenSnapshot.exists) {
        lastToken = tokenSnapshot.data()?['lastToken'] ?? 0;
        lastDate = tokenSnapshot.data()?['lastDate'] ?? "";
      }
      final logicalToday = DateTime.now().subtract(const Duration(hours: 5));
      final dateStr = DateFormat('yyyy-MM-dd').format(logicalToday);
      int nextToken = 1;
      if (lastDate == dateStr) {
        nextToken = lastToken + 1;
      }

      final formattedId = nextId.toString().padLeft(6, '0');
      final formattedTokenId = nextToken.toString().padLeft(3, '0');

      final newOrder = order.copyWith(
        id: docRef.id,
        orderId: formattedId,
        tokenId: formattedTokenId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        statusHistory: [
          { 'status': 'Pending', 'timestamp': DateTime.now(), 'updatedBy': order.cashierId }
        ],
      );

      // Write all three documents in parallel using a batch
      final batch = _firestore.batch();
      batch.set(counterRef, {'lastUsedId': nextId});
      batch.set(tokenCounterRef, {'lastToken': nextToken, 'lastDate': dateStr});
      batch.set(docRef, newOrder.toMap());
      await batch.commit();

      return docRef.id;
    } catch (e) {
      throw Exception("Failed to place order: $e");
    }
  }

  @override
  Future<void> updateOrderDetails(OrderModel order) async {
    final docRef = _firestore.collection('orders').doc(order.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Order not found");
      
      final existing = OrderModel.fromMap(snapshot.data()!, snapshot.id);
      final history = List<Map<String, dynamic>>.from(existing.statusHistory);
      
      history.add({
        'status': '${existing.status} (Edited)',
        'timestamp': DateTime.now(),
        'updatedBy': order.cashierId,
      });

      final updated = order.copyWith(
        statusHistory: history,
        createdAt: existing.createdAt, // Preserve original creation timestamp
        updatedAt: DateTime.now(),
      );

      transaction.set(docRef, updated.toMap());
    });
  }

  @override
  Future<void> updateOrderStatus(String docId, String status, String userId, String role) async {
    final docRef = _firestore.collection('orders').doc(docId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Order not found");

      final order = OrderModel.fromMap(snapshot.data()!, snapshot.id);
      final oldStatus = order.status;
      final history = List<Map<String, dynamic>>.from(order.statusHistory);
      
      history.add({
        'status': status,
        'timestamp': DateTime.now(),
        'updatedBy': userId,
      });

      transaction.update(docRef, {
        'status': status,
        'statusHistory': history,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write activity log if changed by Expediter
      if (role == "expediter") {
        final logRef = _firestore.collection('activity_logs').doc();
        // Read expediter name
        final userSnap = await _firestore.collection('users').doc(userId).get();
        final name = userSnap.data()?['name'] ?? 'Expediter';

        final log = ActivityLogModel(
          id: logRef.id,
          orderId: order.orderId,
          previousStatus: oldStatus,
          newStatus: status,
          expediterId: userId,
          expediterName: name,
          timestamp: DateTime.now(),
        );

        transaction.set(logRef, log.toMap());
      }
    });
  }

  @override
  Future<void> updateOrderPaymentStatus(String docId, bool isPaid, String userId, {double? amountReceived, double? change}) async {
    final docRef = _firestore.collection('orders').doc(docId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Order not found");

      final order = OrderModel.fromMap(snapshot.data()!, snapshot.id);
      final history = List<Map<String, dynamic>>.from(order.statusHistory);
      
      final updates = <String, dynamic>{
        'isPaid': isPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (amountReceived != null) {
        updates['amountReceived'] = amountReceived;
      }
      if (change != null) {
        updates['change'] = change;
      }
      
      if (!isPaid && order.status == "Completed") {
        history.add({
          'status': 'Handover',
          'timestamp': DateTime.now(),
          'updatedBy': userId,
        });
        updates['status'] = 'Handover';
        updates['statusHistory'] = history.map((h) => {
          'status': h['status'],
          'timestamp': parseDateTime(h['timestamp']).toUtc().toIso8601String(),
          'updatedBy': h['updatedBy']
        }).toList();
      } else if (isPaid && order.status == "Handover") {
        history.add({
          'status': 'Completed',
          'timestamp': DateTime.now(),
          'updatedBy': userId,
        });
        updates['status'] = 'Completed';
        updates['statusHistory'] = history.map((h) => {
          'status': h['status'],
          'timestamp': parseDateTime(h['timestamp']).toUtc().toIso8601String(),
          'updatedBy': h['updatedBy']
        }).toList();
      }

      transaction.update(docRef, updates);
    });
  }

  @override
  Future<void> cancelOrder(String docId, String reason, String userId) async {
    final docRef = _firestore.collection('orders').doc(docId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Order not found");

      final order = OrderModel.fromMap(snapshot.data()!, snapshot.id);
      final history = List<Map<String, dynamic>>.from(order.statusHistory);

      history.add({
        'status': 'Cancelled',
        'timestamp': DateTime.now(),
        'updatedBy': userId,
      });

      transaction.update(docRef, {
        'status': 'Cancelled',
        'statusHistory': history,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> undoStatusChange(String docId, List<Map<String, dynamic>> previousHistory, String previousStatus) async {
    // To undo status change:
    final docRef = _firestore.collection('orders').doc(docId);
    
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      final order = OrderModel.fromMap(snap.data()!, snap.id);
      final humanId = order.orderId;

      transaction.update(docRef, {
        'status': previousStatus,
        'statusHistory': previousHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Query the last activity log and delete it
      final logQuery = await _firestore
          .collection('activity_logs')
          .where('orderId', isEqualTo: humanId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (logQuery.docs.isNotEmpty) {
        transaction.delete(logQuery.docs.first.reference);
      }
    });
  }

  @override
  Future<void> updateOrderRider(String docId, String riderName) async {
    final docRef = _firestore.collection('orders').doc(docId);
    await docRef.update({
      'riderName': riderName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<DailyClosingModel?> watchDailyClosing(String date) {
    return _firestore
        .collection('daily_closings')
        .doc(date)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return DailyClosingModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Future<void> saveDailyClosing(DailyClosingModel closing) async {
    await _firestore
        .collection('daily_closings')
        .doc(closing.id)
        .set(closing.toMap());
  }

  @override
  Future<void> releaseDailyClosing(String date) async {
    await _firestore
        .collection('daily_closings')
        .doc(date)
        .update({'isReleased': true});
  }
}

class FirebaseSettingsRepository implements SettingsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<SettingsModel> getSettings() async {
    final doc = await _firestore.collection('restaurant_settings').doc('default').get();
    if (!doc.exists) {
      // Return default
      return SettingsModel(
        id: 'default',
        phoneNumber: '03001234567',
        deliveryCharges: 50.0,
        taxRate: 5.0,
        updatedAt: DateTime.now(),
        cashierReportPassword: '',
        accountDetails: '',
      );
    }
    return SettingsModel.fromMap(doc.data()!, doc.id);
  }

  @override
  Stream<SettingsModel> watchSettings() {
    return _firestore.collection('restaurant_settings').doc('default').snapshots().map((doc) {
      if (!doc.exists) {
        return SettingsModel(
          id: 'default',
          phoneNumber: '03001234567',
          deliveryCharges: 50.0,
          taxRate: 5.0,
          updatedAt: DateTime.now(),
          cashierReportPassword: '',
          accountDetails: '',
        );
      }
      return SettingsModel.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    await _firestore.collection('restaurant_settings').doc('default').set(settings.toMap());
  }
}

class FirebaseActivityLogRepository implements ActivityLogRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<ActivityLogModel>> watchActivityLogs() {
    return _firestore
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityLogModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> logActivity(ActivityLogModel log) async {
    await _firestore.collection('activity_logs').doc(log.id).set(log.toMap());
  }
}

class FirebaseStaffRepository implements StaffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<WaiterModel>> watchWaiters() {
    return _firestore
        .collection('waiters')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => WaiterModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> addWaiter(WaiterModel waiter) async {
    final docRef = _firestore.collection('waiters').doc();
    final newWaiter = waiter.copyWith(id: docRef.id);
    await docRef.set(newWaiter.toMap());
  }

  @override
  Future<void> editWaiter(WaiterModel waiter) async {
    await _firestore.collection('waiters').doc(waiter.id).update(waiter.toMap());
  }

  @override
  Future<void> deleteWaiter(String id) async {
    await _firestore.collection('waiters').doc(id).delete();
  }

  @override
  Stream<List<RiderModel>> watchRiders() {
    return _firestore
        .collection('riders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RiderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> addRider(RiderModel rider) async {
    final docRef = _firestore.collection('riders').doc();
    final newRider = rider.copyWith(id: docRef.id);
    await docRef.set(newRider.toMap());
  }

  @override
  Future<void> editRider(RiderModel rider) async {
    await _firestore.collection('riders').doc(rider.id).update(rider.toMap());
  }

  @override
  Future<void> deleteRider(String id) async {
    await _firestore.collection('riders').doc(id).delete();
  }
}
