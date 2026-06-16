import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../models/order_model.dart';
import '../../../../providers/order_provider.dart';
import '../../../../services/pdf_service.dart';
import '../../../theme/app_theme.dart';
import '../../order_detail_screen.dart';

class HistorialTab extends StatefulWidget {
  final Function(Order) onEditOrder;

  const HistorialTab({
    super.key,
    required this.onEditOrder,
  });

  @override
  State<HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends State<HistorialTab> {
  DateTimeRange? _dateRange;
  String? _clientFilter;

  String _clientLabel(Order order) =>
      order.clientName.isNotEmpty ? order.clientName : order.clientId;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  bool get _hasActiveFilters => _dateRange != null || _clientFilter != null;

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.orders.isEmpty) {
          return const Center(child: Text('No hay registros de despachos.'));
        }

        final clientNames = provider.orders.map(_clientLabel).toSet().toList()
          ..sort();

        final filteredOrders = provider.orders.where((order) {
          if (_dateRange != null) {
            final d = DateUtils.dateOnly(order.scheduledDate);
            final start = DateUtils.dateOnly(_dateRange!.start);
            final end = DateUtils.dateOnly(_dateRange!.end);
            if (d.isBefore(start) || d.isAfter(end)) return false;
          }
          if (_clientFilter != null && _clientLabel(order) != _clientFilter) {
            return false;
          }
          return true;
        }).toList();

        final Map<String, List<Order>> groupedOrders = {};
        for (var order in filteredOrders) {
          final dateStr = DateFormat('dd/MM/yyyy').format(order.scheduledDate);
          groupedOrders.putIfAbsent(dateStr, () => []).add(order);
        }

        final sortedDates = groupedOrders.keys.toList()
          ..sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a);
            final dateB = DateFormat('dd/MM/yyyy').parse(b);
            return dateB.compareTo(dateA);
          });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _dateRange == null
                          ? 'Filtrar por fecha'
                          : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}',
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _clientFilter,
                      hint: const Text('Filtrar por cliente'),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos los clientes'),
                        ),
                        ...clientNames.map(
                          (name) => DropdownMenuItem<String>(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _clientFilter = v),
                    ),
                  ),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _dateRange = null;
                        _clientFilter = null;
                      }),
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filteredOrders.isEmpty
                  ? const Center(
                      child: Text('No hay pedidos que coincidan con los filtros.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final dateStr = sortedDates[dateIndex];
                        final ordersForDate = groupedOrders[dateStr]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 0,
                              color: AppTheme.primaryBlue.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${ordersForDate.length} pedidos',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        color: Colors.red,
                                        size: 22,
                                      ),
                                      onPressed: () async {
                                        final path =
                                            await PdfService.generateDailyReport(
                                          ordersForDate,
                                        );
                                        provider.addGeneratedReport(
                                            dateStr, 'PDF', path);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Reporte PDF generado exitosamente',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      tooltip: 'Exportar PDF',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.table_view,
                                        color: Colors.green,
                                        size: 22,
                                      ),
                                      onPressed: () async {
                                        final path =
                                            await PdfService.generateCSVReport(
                                          ordersForDate,
                                          dateStr,
                                        );
                                        provider.addGeneratedReport(
                                            dateStr, 'Excel', path);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Reporte Excel (CSV) generado exitosamente',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      tooltip: 'Exportar Excel (CSV)',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...ordersForDate.map((order) {
                              final punctuality =
                                  provider.getPunctualityStatus(order);
                              final isLate = punctuality.startsWith('Atrasado');

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isLate
                                        ? AppTheme.errorColor
                                        : Colors.grey.shade100,
                                    width: isLate ? 1.5 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            OrderDetailScreen(order: order),
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: order.status == 'Entregado'
                                        ? const Color(0xFFE6F4EA)
                                        : (order.status == 'Incidencia'
                                            ? const Color(0xFFFCE8E6)
                                            : Colors.grey.shade100),
                                    child: Icon(
                                      order.status == 'Entregado'
                                          ? Icons.check
                                          : (order.status == 'Incidencia'
                                              ? Icons.warning
                                              : Icons.local_shipping),
                                      color: order.status == 'Entregado'
                                          ? Colors.green
                                          : (order.status == 'Incidencia'
                                              ? Colors.red
                                              : Colors.blue),
                                    ),
                                  ),
                                  title: Text(
                                    'Pedido #${order.id}',
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${order.address}\nEstado: ${order.status} | $punctuality',
                                    style: isLate
                                        ? const TextStyle(
                                            color: AppTheme.errorColor,
                                            fontWeight: FontWeight.w600,
                                          )
                                        : null,
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (order.status == 'Pendiente' ||
                                          order.status == 'Anulado')
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'Anular') {
                                              provider.updateOrderStatus(
                                                order.id!,
                                                'Anulado',
                                              );
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Pedido anulado.'),
                                                ),
                                              );
                                            } else if (value == 'Eliminar') {
                                              provider.deleteOrder(order.id!);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Pedido eliminado.'),
                                                ),
                                              );
                                            } else if (value == 'Editar') {
                                              widget.onEditOrder(order);
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                              <PopupMenuEntry<String>>[
                                            if (order.status == 'Pendiente')
                                              const PopupMenuItem<String>(
                                                value: 'Editar',
                                                child: Text('Editar'),
                                              ),
                                            if (order.status == 'Pendiente')
                                              const PopupMenuItem<String>(
                                                value: 'Anular',
                                                child: Text(
                                                  'Anular',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ),
                                            if (order.status == 'Anulado')
                                              const PopupMenuItem<String>(
                                                value: 'Eliminar',
                                                child: Text(
                                                  'Eliminar',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
