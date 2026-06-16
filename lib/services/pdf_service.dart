import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<String> generateDailyReport(List<Order> orders) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(orders.first.scheduledDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('QÚBICO TRANSPORTES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, fontSize: 18)),
                pw.Text('Reporte Diario de Despachos', style: pw.TextStyle(color: PdfColors.grey700)),
              ],
            ),
            pw.Divider(color: PdfColors.orange800, thickness: 2),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Fecha del reporte: $dateStr'),
              pw.Text('Total de servicios: ${orders.length}'),
            ],
          ),
          pw.SizedBox(height: 20),
          _buildOrdersTable(orders),
          pw.SizedBox(height: 30),
          _buildSummary(orders),
        ],
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Documento generado automáticamente por Sistema Qúbico', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    
    // Save to a local file for the Reports history tab
    final directory = await getTemporaryDirectory();
    final sanitizeDate = dateStr.replaceAll('/', '-');
    final file = File('${directory.path}/Reporte_Qubico_$sanitizeDate.pdf');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  static Future<String> generateCSVReport(List<Order> orders, String dateStr) async {
    final buffer = StringBuffer();
    // Cabecera CSV
    buffer.writeln('ID,Cliente,Direccion,Peso,Ventana,Estado,Puntualidad');
    for (var o in orders) {
      final punctuality = _calculatePunctuality(o);
      buffer.writeln('${o.id},"${o.clientId}","${o.address}",${o.weight},"${o.timeWindow}","${o.status}","$punctuality"');
    }
    
    final directory = await getTemporaryDirectory();
    final sanitizeDate = dateStr.replaceAll('/', '-');
    final file = File('${directory.path}/Reporte_Qubico_$sanitizeDate.csv');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  static String _calculatePunctuality(Order order) {
    if (order.status != 'Entregado') return '-';
    if (order.deliveryTime == null) return '-';
    final diff = _delayMinutes(order);
    if (diff != null) return 'Atrasado ($diff min)';
    return 'A tiempo';
  }

  /// Minutos de atraso respecto al fin de la ventana horaria. Devuelve null
  /// si el pedido no ha sido entregado o si fue entregado a tiempo.
  static int? _delayMinutes(Order order) {
    if (order.status != 'Entregado' || order.deliveryTime == null) {
      return null;
    }

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
      return order.deliveryTime!.difference(endWindow).inMinutes;
    }
    return null;
  }

  static pw.Widget _buildOrdersTable(List<Order> orders) {
    const headers = [
      'ID',
      'Cliente',
      'Dirección',
      'Ventana',
      'Estado',
      'Puntualidad',
    ];

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...orders.map((o) {
          final delay = _delayMinutes(o);
          // RNF/HU06: resaltar en rojo entregas con más de 15 minutos de atraso.
          final isLate = delay != null && delay > 15;
          final cells = [
            o.id.toString(),
            o.clientId,
            o.address,
            o.timeWindow,
            o.status,
            _calculatePunctuality(o),
          ];

          return pw.TableRow(
            decoration: isLate
                ? const pw.BoxDecoration(color: PdfColors.red50)
                : null,
            children: cells
                .map(
                  (c) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      c,
                      style: isLate
                          ? pw.TextStyle(
                              color: PdfColors.red900,
                              fontWeight: pw.FontWeight.bold,
                            )
                          : null,
                    ),
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSummary(List<Order> orders) {
    final delivered = orders.where((o) => o.status == 'Entregado').length;
    final incidents = orders.where((o) => o.status == 'Incidencia').length;
    final pending = orders.where((o) => o.status == 'Pendiente' || o.status == 'En camino').length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RESUMEN DE OPERACIÓN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 5),
          pw.Text('Servicios Completados: $delivered'),
          pw.Text('Incidencias Reportadas: $incidents'),
          pw.Text('Pendientes de Gestión: $pending'),
        ],
      ),
    );
  }
}
