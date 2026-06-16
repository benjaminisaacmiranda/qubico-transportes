import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/database_service.dart';

class OrderProvider with ChangeNotifier {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  static const Map<String, List<String>> _validTransitions = {
    'Pendiente': ['En camino', 'Incidencia', 'Anulado'],
    'En camino': ['Entregado', 'Incidencia'],
    'Incidencia': ['Pendiente', 'En camino'],
    'Entregado': [],
    'Anulado': [],
  };

  final List<Map<String, dynamic>> _generatedReports = [];
  List<Map<String, dynamic>> get generatedReports =>
      List.unmodifiable(_generatedReports);

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  static const int _maxStoredReports = 50;

  void addGeneratedReport(String date, String type, String filePath) {
    _generatedReports.add({
      'date': date,
      'type': type,
      'generatedAt': DateTime.now().toIso8601String(),
      'filePath': filePath,
    });
    // RNF-07: conservar solo los 50 reportes más recientes en memoria.
    while (_generatedReports.length > _maxStoredReports) {
      _generatedReports.removeAt(0);
    }
    notifyListeners();
  }

  /// Inicia un stream de Firestore. Llama esto desde initState de cada pantalla principal.
  /// [isAdmin] = true trae todos los pedidos; false filtra por UID del conductor autenticado.
  void startListening({required bool isAdmin}) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('orders');

    if (!isAdmin) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        query = query.where('driverId', isEqualTo: uid);
      }
    }

    _subscription = query.snapshots().listen(
      (snapshot) {
        _orders = snapshot.docs
            .map((doc) => Order.fromFirestore(doc))
            .toList();
        _sortOrders();
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Firestore orders stream error: $e');
        _errorMessage = 'Error al cargar pedidos: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Alias para compatibilidad con pantallas existentes que llaman fetchOrders().
  Future<void> fetchOrders({bool isAdmin = false}) async {
    startListening(isAdmin: isAdmin);
  }

  void _sortOrders() {
    const priority = {
      'En camino': 0,
      'Pendiente': 1,
      'Incidencia': 2,
      'Entregado': 3,
      'Anulado': 4,
    };
    _orders.sort((Order a, Order b) {
      final pa = priority[a.status] ?? 99;
      final pb = priority[b.status] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      final aStart = a.timeWindow.split(' - ').first;
      final bStart = b.timeWindow.split(' - ').first;
      final cmp = aStart.compareTo(bStart);
      if (cmp == 0) return (a.id ?? '').compareTo(b.id ?? '');
      return cmp;
    });
  }

  Future<void> addOrder(Order order, {String userId = 'Sistema'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(order.toFirestore());

      await DatabaseService.instance.insert('audit_logs', {
        'user_id': userId,
        'action': 'Creación Pedido #${docRef.id}',
        'timestamp': DateTime.now().toIso8601String(),
        'old_value': 'Ninguno',
        'new_value': 'Creado y asignado a ${order.driverId}',
      });
    } catch (e) {
      debugPrint('Error in addOrder: $e');
      _errorMessage = 'Error al crear pedido: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrderStatus(
    String id,
    String newStatus, {
    String? incidentReason,
    String? evidencePath,
    String? signaturePath,
    String userId = 'Sistema',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String oldStatus = 'Pendiente';
    try {
      oldStatus = _orders.firstWhere((o) => o.id == id).status;
    } catch (_) {}

    final allowedTransitions = _validTransitions[oldStatus] ?? [];
    if (!allowedTransitions.contains(newStatus)) {
      _errorMessage =
          'Transición de estado no permitida: "$oldStatus" → "$newStatus"';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final Map<String, dynamic> updates = {
        'status': newStatus,
        'deliveryTime': FieldValue.serverTimestamp(),
      };
      if (incidentReason != null) updates['incidentReason'] = incidentReason;
      if (evidencePath != null) updates['evidencePath'] = evidencePath;
      if (signaturePath != null) updates['signaturePath'] = signaturePath;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(id)
          .update(updates);

      await DatabaseService.instance.insert('audit_logs', {
        'user_id': userId,
        'action': 'Actualización Estado Pedido #$id',
        'timestamp': DateTime.now().toIso8601String(),
        'old_value': oldStatus,
        'new_value':
            newStatus + (incidentReason != null ? ' ($incidentReason)' : ''),
      });
    } catch (e) {
      debugPrint('Error in updateOrderStatus: $e');
      _errorMessage = 'Error al actualizar estado: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrder(Order order, {String userId = 'Sistema'}) async {
    if (order.id == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id!)
          .set(order.toFirestore());
    } catch (e) {
      debugPrint('Error in updateOrder: $e');
      _errorMessage = 'Error al actualizar pedido: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteOrder(String id, {String userId = 'Sistema'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('orders').doc(id).delete();

      await DatabaseService.instance.insert('audit_logs', {
        'user_id': userId,
        'action': 'Eliminación Pedido #$id',
        'timestamp': DateTime.now().toIso8601String(),
        'old_value': 'Existente',
        'new_value': 'Eliminado',
      });
    } catch (e) {
      debugPrint('Error in deleteOrder: $e');
      _errorMessage = 'Error al eliminar pedido: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogsForOrder(
      String orderId) async {
    try {
      final db = await DatabaseService.instance.database;
      final data = await db.query(
        'audit_logs',
        where: 'action LIKE ?',
        whereArgs: ['%#$orderId%'],
      );
      return data;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalAuditLogs() async {
    try {
      final db = await DatabaseService.instance.database;
      final logs = await db.query('audit_logs', orderBy: 'timestamp DESC');
      return logs;
    } catch (_) {
      return [];
    }
  }

  String getPunctualityStatus(Order order) {
    if (order.deliveryTime == null) return 'Pendiente';
    final endWindowStr = order.timeWindow.split(' - ').last;
    final parts = endWindowStr.split(':');
    final endWindow = DateTime(
      order.scheduledDate.year,
      order.scheduledDate.month,
      order.scheduledDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (order.deliveryTime!.isAfter(endWindow)) {
      final diff = order.deliveryTime!.difference(endWindow).inMinutes;
      return 'Atrasado ($diff min)';
    }
    return 'A tiempo';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
