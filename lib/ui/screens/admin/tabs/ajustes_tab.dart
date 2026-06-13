import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:qubico/providers/vehicle_provider.dart';
import 'package:qubico/ui/theme/app_theme.dart';
import 'package:qubico/ui/screens/fleet_management_screen.dart';
import 'package:qubico/ui/screens/user_management_screen.dart';
import 'package:qubico/ui/screens/reports_screen.dart';

class AjustesTab extends StatelessWidget {
  const AjustesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Configuraciones y Módulos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildAjustesTile(
          icon: Icons.local_shipping_outlined,
          title: 'Gestión de Flota',
          subtitle: 'Monitorear, agregar y editar vehículos corporativos',
          onTap: () {
            context.read<VehicleProvider>().fetchVehicles();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FleetManagementScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildAjustesTile(
          icon: Icons.people_outline,
          title: 'Gestión de Usuarios y Seguridad',
          subtitle: 'Controlar accesos, roles y bitácora de auditoría',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildAjustesTile(
          icon: Icons.analytics_outlined,
          title: 'Reportes y Exportaciones',
          subtitle: 'Exportación de datos de despachos en PDF y Excel',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAjustesTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.08),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}