import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../utils/validators.dart';
import '../theme/app_theme.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración de Seguridad y Perfiles'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Gestión de Cuentas'),
              Tab(text: 'Bitácora de Auditoría'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAccountsTab(context),
            _buildAuditTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddUserDialog(context),
          backgroundColor: AppTheme.accentOrange,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAccountsTab(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, child) {
        if (provider.users.isEmpty) {
          return const Center(child: Text('No hay usuarios registrados'));
        }

        return ListView.builder(
          itemCount: provider.users.length,
          itemBuilder: (context, index) {
            final user = provider.users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.isActive ? AppTheme.primaryBlue : Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(user.fullName, style: TextStyle(
                  decoration: user.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                  color: user.isActive ? Colors.black : Colors.grey,
                )),
                subtitle: Text('${user.email}\nRol: ${user.role.name.toUpperCase()}'),
                isThreeLine: true,
                trailing: Switch(
                  value: user.isActive,
                  onChanged: (value) {
                    provider.toggleUserStatus(user.id, user.isActive);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: AppTheme.primaryBlue),
            title: const Text('Auditoría del Sistema'),
            subtitle: const Text('El usuario [Admin_Luis] modificó el [Estado_Pedido] del ID #450 de [Pendiente] a [Anulado] el día 18/05/2026 a las 14:00 hrs.'),
          ),
        ),
      ],
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.conductor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Usuario'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'RUT'),
                  validator: Validators.validateRut,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre Completo'),
                  validator: (v) => Validators.validateRequired(v, 'El nombre'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Debe contener una mayúscula';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Debe contener un número';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  items: UserRole.values.map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  )).toList(),
                  onChanged: (v) => selectedRole = v!,
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newUser = User(
                  id: idController.text,
                  fullName: nameController.text,
                  email: emailController.text,
                  role: selectedRole,
                );
                context.read<UserProvider>().addUser(newUser);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Usuario creado exitosamente')),
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
}
