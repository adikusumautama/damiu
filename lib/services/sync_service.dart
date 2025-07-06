// lib/services/sync_service.dart
import 'dart:async';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> syncCustomers() async {
    final unsyncedCustomers = await _dbHelper.getUnsyncedCustomers();
    if (unsyncedCustomers.isEmpty) return;
    for (var customer in unsyncedCustomers) {
      if (customer.name.trim().isEmpty) continue;
      try {
        if (customer.firestoreId == null || customer.firestoreId!.isEmpty) {
          final newId = await _firestoreService.addCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, newId);
        } else {
          await _firestoreService.updateCustomer(customer);
          await _dbHelper.markCustomerAsSynced(customer.id!, customer.firestoreId!);
        }
      } catch (e) { /* Log error */ }
    }
  }

  Future<void> syncOrders() async {
    final unsyncedOrders = await _dbHelper.getUnsyncedOrders();
    if (unsyncedOrders.isEmpty) return;
    for (var order in unsyncedOrders) {
      try {
        if (order.firestoreId == null || order.firestoreId!.isEmpty) {
          final newId = await _firestoreService.addOrderAndUpsertCustomer(order);
          if (newId != null) await _dbHelper.markOrderAsSynced(order.id!, newId);
        } else if (order.status == OrderStatus.delivered) {
          final error = await _firestoreService.completeOrderTransaction(order);
          if (error == null) await _dbHelper.markOrderAsSynced(order.id!, order.firestoreId!);
        } else {
          final error = await _firestoreService.updateOrderStatus(order.firestoreId!, order.status ?? '');
          if (error == null) await _dbHelper.markOrderAsSynced(order.id!, order.firestoreId!);
        }
      } catch (e) { /* Log error */ }
    }
  }
  
  Future<void> pullAllDataFromFirestore() async {
    final customers = await _firestoreService.getAllCustomersOnce();
    for (final c in customers) { await _dbHelper.upsertCustomer(c); }
    final orders = await _firestoreService.getAllOrdersOnce();
    for (final o in orders) { await _dbHelper.upsertOrder(o); }
  }

  StreamSubscription listenToFirestoreChanges() {
    return Stream.fromFutures([
      _firestoreService.getCustomersStream().first,
      _firestoreService.getOrdersStream().first,
      _firestoreService.getStocksStream().first,
    ]).listen((_) async => await pullAllDataFromFirestore());
  }

  Future<void> syncAllData() async {
    await syncCustomers();
    await syncOrders();
    await pullAllDataFromFirestore();
  }
}