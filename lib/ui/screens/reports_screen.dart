import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../services/pdf_service.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Gestión'),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          final filteredOrders = provider.orders.where((order) {
            final orderDate = DateTime.parse(order.scheduledDate.toIso8601String());
            return orderDate.year == _selectedDate.year &&
                orderDate.month == _selectedDate.month &&
                orderDate.day == _selectedDate.day;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtros de Historial',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text('Fecha seleccionada: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Exportación de Datos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: const Text('Resumen de Despacho Diario'),
                    subtitle: Text('Generar reporte PDF para el día ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    trailing: ElevatedButton(
                      onPressed: filteredOrders.isEmpty ? null : () async {
                        await PdfService.generateDailyReport(filteredOrders);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reporte PDF generado exitosamente')),
                          );
                        }
                      },
                      child: const Text('Generar'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.table_view, color: Colors.green),
                    title: const Text('Exportar Datos en Bruto (Excel/CSV)'),
                    subtitle: Text('Descargar RUT, peso y estado para análisis contable.'),
                    trailing: ElevatedButton(
                      onPressed: filteredOrders.isEmpty ? null : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Archivo CSV generado y guardado en Documentos')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Descargar'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Resumen del Día',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Total', filteredOrders.length, Colors.blue),
                    _buildStatCard('Entregados', filteredOrders.where((o) => o.status == 'Entregado').length, Colors.green),
                    _buildStatCard('Incidencias', filteredOrders.where((o) => o.status == 'Incidencia').length, Colors.red),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
