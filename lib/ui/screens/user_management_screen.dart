import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/validators.dart';
import '../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Seguridad y Perfiles'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gestión de Cuentas'),
            Tab(text: 'Bitácora de Auditoría'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountsTab(),
          _buildAuditTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(),
        backgroundColor: AppTheme.accentOrange,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ================= USERS LIST =================
  Widget _buildAccountsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return const Center(child: Text('No hay usuarios registrados'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(data['fullName'] ?? 'Sin nombre'),
                subtitle: Text(
                  '${data['correo']}\nRol: ${data['rol']}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  // ================= AUDIT (mock) =================
  Widget _buildAuditTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.history, color: AppTheme.primaryBlue),
            title: Text('Auditoría del Sistema'),
            subtitle: Text(
              'Sistema de auditoría activo (pendiente integración real)',
            ),
          ),
        ),
      ],
    );
  }

  // ================= CREATE USER =================
  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    String selectedRole = 'usuario';

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
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      Validators.validateRequired(v, 'El nombre'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  decoration:
                      const InputDecoration(labelText: 'Correo'),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordController,
                  decoration:
                      const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('ADMINISTRADOR'),
                    ),
                    DropdownMenuItem(
                      value: 'usuario',
                      child: Text('USUARIO'),
                    ),
                  ],
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  // 🔐 Crear usuario en Auth
                  final cred = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );

                  final uid = cred.user!.uid;

                  // 📦 Guardar en Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .set({
                    'correo': emailController.text.trim(),
                    'fullName': nameController.text.trim(),
                    'rut': idController.text.trim(),
                    'rol': selectedRole,
                    'isActive': true,
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usuario creado exitosamente'),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Error')),
                  );
                }
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }
}