import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../models/order_model.dart';
import '../../../../providers/order_provider.dart';
import '../../../../services/pdf_service.dart';
import '../../../theme/app_theme.dart';
import '../../order_detail_screen.dart';

class HistorialTab extends StatelessWidget {
  final Function(Order) onEditOrder;

  const HistorialTab({
    super.key,
    required this.onEditOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.orders.isEmpty) {
          return const Center(child: Text('No hay registros de despachos.'));
        }

        final Map<String, List<Order>> groupedOrders = {};
        for (var order in provider.orders) {
          final dateStr = DateFormat('dd/MM/yyyy').format(order.scheduledDate);
          groupedOrders.putIfAbsent(dateStr, () => []).add(order);
        }

        final sortedDates = groupedOrders.keys.toList()
          ..sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a);
            final dateB = DateFormat('dd/MM/yyyy').parse(b);
            return dateB.compareTo(dateA);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
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
                            final path = await PdfService.generateDailyReport(
                              ordersForDate,
                            );
                            provider.addGeneratedReport(dateStr, 'PDF', path);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
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
                            final path = await PdfService.generateCSVReport(
                              ordersForDate,
                              dateStr,
                            );
                            provider.addGeneratedReport(dateStr, 'Excel', path);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
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
                  final punctuality = provider.getPunctualityStatus(order);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(order: order),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${order.address}\nEstado: ${order.status} | $punctuality',
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pedido anulado.'),
                                    ),
                                  );
                                } else if (value == 'Eliminar') {
                                  provider.deleteOrder(order.id!);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pedido eliminado.'),
                                    ),
                                  );
                                } else if (value == 'Editar') {
                                  // Llamamos al callback para editar y navegar
                                  onEditOrder(order);
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
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    if (order.status == 'Anulado')
                                      const PopupMenuItem<String>(
                                        value: 'Eliminar',
                                        child: Text(
                                          'Eliminar',
                                          style: TextStyle(color: Colors.red),
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
        );
      },
    );
  }
}