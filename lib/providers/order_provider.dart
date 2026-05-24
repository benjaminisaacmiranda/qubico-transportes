import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';

class OrderProvider with ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Valid status transitions map
  static const Map<String, List<String>> _validTransitions = {
    'Pendiente': ['En camino', 'Incidencia'],
    'En camino': ['Entregado', 'Incidencia'],
    'Incidencia': ['Pendiente', 'En camino'],
    'Entregado': [], // terminal state
  };

  final List<Map<String, dynamic>> _generatedReports = [];
  List<Map<String, dynamic>> get generatedReports => List.unmodifiable(_generatedReports);

  void addGeneratedReport(String date, String type, String filePath) {
    _generatedReports.add({
      'date': date,
      'type': type,
      'generatedAt': DateTime.now().toIso8601String(),
      'filePath': filePath,
    });
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await DatabaseService.instance.queryAll('orders');
      _orders = data.map((e) => Order.fromMap(e)).toList();
    } catch (e) {
      debugPrint('DB Error in fetchOrders, using resilient in-memory fallback: $e');
      _errorMessage = 'Error al cargar pedidos: $e';
      if (_orders.isEmpty) {
        _orders = [];
      }
    } finally {
      // RF6: Sort by time window start, then FIFO
      _sortOrders();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortOrders() {
    _orders.sort((a, b) {
      // Simple parse of "HH:mm - HH:mm"
      final aStart = a.timeWindow.split(' - ').first;
      final bStart = b.timeWindow.split(' - ').first;

      int cmp = aStart.compareTo(bStart);
      if (cmp == 0) {
        // FIFO: Assuming lower ID means registered earlier
        return (a.id ?? 0).compareTo(b.id ?? 0);
      }
      return cmp;
    });
  }

  Future<void> addOrder(Order order, {String userId = 'Sistema'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await DatabaseService.instance.insert('orders', order.toMap());

      // Log creation in audit trail
      await DatabaseService.instance.insert('audit_logs', {
        'user_id': userId,
        'action': 'Creación Pedido #$id',
        'timestamp': DateTime.now().toIso8601String(),
        'old_value': 'Ninguno',
        'new_value': 'Creado y Asignado a ${order.driverId}',
      });

      await fetchOrders();
    } catch (e) {
      debugPrint('DB Error in addOrder, performing resilient in-memory add: $e');
      _errorMessage = 'Error al crear pedido: $e';
      final newId = _orders.isEmpty ? 1 : (_orders.map((o) => o.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      final newOrder = Order(
        id: newId,
        clientId: order.clientId,
        weight: order.weight,
        height: order.height,
        length: order.length,
        width: order.width,
        loadType: order.loadType,
        timeWindow: order.timeWindow,
        address: order.address,
        status: order.status,
        scheduledDate: order.scheduledDate,
        driverId: order.driverId,
      );
      _orders.add(newOrder);
      _sortOrders();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrderStatus(
    int id,
    String newStatus, {
    String? incidentReason,
    String? evidencePath,
    String? signaturePath,
    String userId = 'Sistema',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Fetch old status for logging and validation
    String oldStatus = 'Pendiente';
    String driver = 'Conductor';
    try {
      final oldOrder = _orders.firstWhere((o) => o.id == id);
      oldStatus = oldOrder.status;
      driver = oldOrder.driverId ?? 'Conductor';
    } catch (_) {}

    // Validate status transition
    final allowedTransitions = _validTransitions[oldStatus] ?? [];
    if (!allowedTransitions.contains(newStatus)) {
      _errorMessage = 'Transición de estado no permitida: "$oldStatus" → "$newStatus"';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final Map<String, dynamic> updates = {
        'status': newStatus,
        'delivery_time': DateTime.now().toIso8601String(),
      };
      if (incidentReason != null) updates['incident_reason'] = incidentReason;
      if (evidencePath != null) updates['evidence_path'] = evidencePath;
      if (signaturePath != null) updates['signature_path'] = signaturePath;

      await DatabaseService.instance.update('orders', updates, 'id', id);

      // Log state transition in audit trail
      await DatabaseService.instance.insert('audit_logs', {
        'user_id': userId,
        'action': 'Actualización Estado Pedido #$id',
        'timestamp': DateTime.now().toIso8601String(),
        'old_value': oldStatus,
        'new_value': newStatus + (incidentReason != null ? ' ($incidentReason)' : ''),
      });

      await fetchOrders();
    } catch (e) {
      debugPrint('DB Error in updateOrderStatus, performing resilient in-memory update: $e');
      _errorMessage = 'Error al actualizar estado: $e';
      final idx = _orders.indexWhere((o) => o.id == id);
      if (idx != -1) {
        final o = _orders[idx];
        _orders[idx] = Order(
          id: o.id,
          clientId: o.clientId,
          weight: o.weight,
          height: o.height,
          length: o.length,
          width: o.width,
          loadType: o.loadType,
          timeWindow: o.timeWindow,
          address: o.address,
          status: newStatus,
          scheduledDate: o.scheduledDate,
          driverId: o.driverId,
          incidentReason: incidentReason ?? o.incidentReason,
          evidencePath: evidencePath ?? o.evidencePath,
          signaturePath: signaturePath ?? o.signaturePath,
          deliveryTime: DateTime.now(),
        );
        _sortOrders();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogsForOrder(int orderId) async {
    try {
      // Use SQL WHERE clause instead of fetching all and filtering in Dart
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
      // Sort by timestamp descending (newest first) via SQL
      final logs = await db.query(
        'audit_logs',
        orderBy: 'timestamp DESC',
      );
      return logs;
    } catch (_) {
      return [];
    }
  }

  Future<void> updateOrder(Order order, {String userId = 'Sistema'}) async {
    if (order.id == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.update('orders', order.toMap(), 'id', order.id);
      await fetchOrders();
    } catch (e) {
      debugPrint('DB Error in updateOrder: $e');
      _errorMessage = 'Error al actualizar pedido: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteOrder(int id, {String userId = 'Sistema'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.delete('orders', 'id', id);

      // Log deletion in audit trail
      await DatabaseService.instance.insert('audit_logs', {
        'user_id': userId,
        'action': 'Eliminación Pedido #$id',
        'timestamp': DateTime.now().toIso8601String(),
        'old_value': 'Existente',
        'new_value': 'Eliminado',
      });

      await fetchOrders();
    } catch (e) {
      debugPrint('DB Error in deleteOrder: $e');
      _errorMessage = 'Error al eliminar pedido: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // RF13: Punctuality Indicator
  String getPunctualityStatus(Order order) {
    if (order.deliveryTime == null) return "Pendiente";

    // Extract end of window "HH:mm"
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
      return "Atrasado ($diff min)";
    }
    return "A tiempo";
  }
}
