import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../providers/order_provider.dart';
import '../../../theme/app_theme.dart';

class InicioTab extends StatelessWidget {
  const InicioTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final total = orderProvider.orders.length;
    final enRuta = orderProvider.orders.where((o) => o.status == 'En camino' || o.status == 'En Ruta').length;
    final entregados = orderProvider.orders.where((o) => o.status == 'Entregado').length;
    final incidencias = orderProvider.orders.where((o) => o.status == 'Incidencia').length;

    final criticalOrders = orderProvider.orders.where((o) {
      if (o.status == 'Entregado' || o.status == 'Anulado') return false;
      return orderProvider.getPunctualityStatus(o).contains('Atrasado');
    }).toList();

    final isSmallScreen = MediaQuery.of(context).size.width < 380;

    return ListView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(
          'Resumen de Operaciones',
          style: TextStyle(
            fontSize: isSmallScreen ? 20 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        
        if (orderProvider.isLoading && total == 0)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: isSmallScreen ? 12 : 16,
            mainAxisSpacing: isSmallScreen ? 12 : 16,
            childAspectRatio: isSmallScreen ? 1.1 : 1.25,
            children: List.generate(4, (index) => _buildSkeletonKPI()),
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: isSmallScreen ? 12 : 16,
            mainAxisSpacing: isSmallScreen ? 12 : 16,
            childAspectRatio: isSmallScreen ? 1.1 : 1.25,
            children: [
              _buildResumenCard(
                icon: Icons.inventory_2_rounded,
                label: 'Total Despachos',
                value: total.toString(),
                primaryColor: AppTheme.primaryBlue,
                isAlert: false,
              ),
              _buildResumenCard(
                icon: Icons.check_circle_rounded,
                label: 'Entregas Exitosas',
                value: entregados.toString(),
                primaryColor: const Color(0xFF137333), 
                isAlert: false,
              ),
              _buildResumenCard(
                icon: Icons.local_shipping_rounded,
                label: 'En Ruta',
                value: enRuta.toString(),
                primaryColor: AppTheme.accentOrange,
                isAlert: false,
              ),
              _buildResumenCard(
                icon: Icons.warning_rounded,
                label: 'Incidencias',
                value: incidencias.toString(),
                primaryColor: AppTheme.errorColor, 
                isAlert: incidencias > 0, 
              ),
            ],
          ),
        
        const SizedBox(height: 32),

        const Text(
          'Distribución de Estados',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              height: 200,
              child: total == 0 
                ? const Center(child: Text('No hay datos para graficar', style: TextStyle(color: Colors.grey)))
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFF137333),
                                value: entregados.toDouble(),
                                title: '${((entregados / total) * 100).toStringAsFixed(0)}%',
                                radius: 45,
                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                              ),
                              PieChartSectionData(
                                color: AppTheme.accentOrange,
                                value: enRuta.toDouble(),
                                title: '${((enRuta / total) * 100).toStringAsFixed(0)}%',
                                radius: 45,
                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                              ),
                              PieChartSectionData(
                                color: AppTheme.errorColor,
                                value: incidencias.toDouble(),
                                title: '${((incidencias / total) * 100).toStringAsFixed(0)}%',
                                radius: 45,
                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem('Entregados', const Color(0xFF137333)),
                            const SizedBox(height: 8),
                            _buildLegendItem('En Ruta', AppTheme.accentOrange),
                            const SizedBox(height: 8),
                            _buildLegendItem('Incidencia', AppTheme.errorColor),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: Colors.black87),
            const SizedBox(width: 8),
            const Text(
              'Alertas Críticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            if (criticalOrders.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${criticalOrders.length} Atrasos',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              )
          ],
        ),
        const SizedBox(height: 16),
        
        criticalOrders.isEmpty
            ? Card(
                elevation: 0,
                color: const Color(0xFFE6F4EA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF137333)),
                      SizedBox(width: 12),
                      Text(
                        'Sin retrasos críticos.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF137333)),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: criticalOrders.map((o) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.errorColor, width: 1.5),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFCE8E6),
                      child: Icon(Icons.timer_off, color: AppTheme.errorColor),
                    ),
                    title: Text(
                      'Pedido #${o.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor),
                    ),
                    subtitle: Text('${o.address}\nExcedió ventana: ${o.timeWindow}'),
                    isThreeLine: true,
                  ),
                )).toList(),
              ),
      ],
    );
  }

  Widget _buildResumenCard({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
    required bool isAlert,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => HapticFeedback.lightImpact(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: isAlert ? AppTheme.errorColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAlert ? AppTheme.errorColor : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isAlert ? Colors.white.withOpacity(0.2) : primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isAlert ? Colors.white : primaryColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isAlert ? Colors.white : Colors.black87,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAlert ? Colors.white70 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonKPI() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
}