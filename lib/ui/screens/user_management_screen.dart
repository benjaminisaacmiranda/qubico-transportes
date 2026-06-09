import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart' as app_models;
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
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
    
    // Carga automática de los usuarios locales al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers de Interfaz ─────────────────────────────────
  /// Retorna un icono representativo dependiendo del rol del usuario
  IconData _roleIcon(String rol) {
    switch (rol) {
      case 'conductor':
        return Icons.drive_eta;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  // PESTAÑA 1: GESTIÓN DE CUENTAS (LISTADO)
  Widget _buildAccountsTab() {
    final userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userProvider.users.isEmpty) {
      return const Center(
        child: Text('No hay usuarios registrados en el sistema local.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userProvider.users.length,
      itemBuilder: (context, index) {
        final user = userProvider.users[index];
        final roleStr = user.role.toString().split('.').last;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.08),
              child: Icon(_roleIcon(roleStr), color: AppTheme.primaryBlue),
            ),
            title: Text(
              user.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('${user.email}\nRol: ${roleStr.toUpperCase()}'),
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Switch para habilitar o deshabilitar acceso del usuario
                Switch(
                  value: user.isActive,
                  activeColor: AppTheme.primaryBlue,
                  onChanged: (value) async {
                    await context.read<UserProvider>().toggleUserStatus(user.id, user.isActive);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar Usuario'),
                        content: Text('¿Está seguro de que desea eliminar a ${user.fullName}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('CANCELAR'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('ELIMINAR', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await context.read<UserProvider>().deleteUser(user.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // PESTAÑA 2: BITÁCORA DE AUDITORÍA
  Widget _buildAuditTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.queryAll('audit_logs'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar la bitácora: ${snapshot.error}'));
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(child: Text('No hay registros en la bitácora de auditoría.'));
        }

        final reversedLogs = logs.reversed.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reversedLogs.length,
          itemBuilder: (context, index) {
            final log = reversedLogs[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade100),
              ),
              child: ListTile(
                leading: Icon(Icons.history_toggle_off, color: Colors.grey.shade600),
                title: Text(
                  log['action'] ?? 'Acción no especificada',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Usuario ID: ${log['user_id']}\nCambio: ${log['old_value']} ➔ ${log['new_value']}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
                trailing: Text(
                  log['timestamp'] != null
                      ? log['timestamp'].toString().substring(0, 16).replaceAll('T', ' ')
                      : '',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  // DIÁLOGO PRINCIPAL: FORMULARIO Y CREACIÓN DE USUARIOS
  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final rutController = TextEditingController();
    String selectedRole = 'conductor';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text('Crear Nuevo Perfil'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value){
                        if (value==null || value.trim().isEmpty) {
                          return 'Porfavor, ingrese un nombre completo';
                        }
                        return null;
                      }
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rutController,
                      decoration: const InputDecoration(
                        labelText: 'RUT',
                        prefixIcon: Icon(Icons.badge),
                        hintText: '12.345.678-9',
                      ),
                      validator: Validators.validateRut,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña Inicial',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      isExpanded: true, // 🎯 SOLUCIÓN: Expande el contenido interno para evitar desbordes visuales de texto
                      decoration: const InputDecoration(
                        labelText: 'Rol del Sistema',
                        prefixIcon: Icon(Icons.admin_panel_settings),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'conductor',
                          child: Text('Conductor / Transportista'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Administrador de Operaciones'),
                        ),
                        DropdownMenuItem(
                          value: 'staff',
                          child: Text('Personal de Soporte'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      try {
                        // 1️⃣ 🔐 Crear en Firebase Auth usando una App Secundaria Temporal sin desloguear al Admin
                        FirebaseApp secondaryApp = await Firebase.initializeApp(
                          name: 'SecondaryApp',
                          options: Firebase.app().options,
                        );
                        
                        FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
                        
                        final cred = await secondaryAuth.createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                        final uid = cred.user!.uid;
                        
                        // Liberar inmediatamente la app secundaria de la memoria
                        await secondaryApp.delete();

                        // Registrar datos ampliados en Firestore (Nube)
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .set({
                              'correo': emailController.text.trim(),
                              'fullName': nameController.text.trim(),
                              'rut': rutController.text.trim(),
                              'rol': selectedRole,
                              'isActive': true,
                            });

                        // 3️⃣ 💾 Sincronizar y persistir localmente en SQLite mediante el UserProvider
                        final appRole = app_models.UserRole.values.firstWhere(
                          (e) => e.toString().split('.').last == selectedRole,
                          orElse: () => app_models.UserRole.staff,
                        );

                        final newUser = app_models.User(
                          id: uid,
                          fullName: nameController.text.trim(),
                          email: emailController.text.trim(),
                          role: appRole,
                          isActive: true,
                        );

                        if (mounted) {
                          await context.read<UserProvider>().addUser(
                            newUser,
                            password: passwordController.text.trim(),
                          );
                        }

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedRole == 'conductor'
                                        ? 'Conductor guardado correctamente.'
                                        : 'Usuario guardado exitosamente.',
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green[700],
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message ?? 'Error de autenticación con Firebase'),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error inesperado: $e'),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('GUARDAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // MÉTODO BUILD PRINCIPAL 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Seguridad y Perfiles'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.manage_accounts), text: 'Gestión de Cuentas'),
            Tab(icon: Icon(Icons.history), text: 'Bitácora de Auditoría'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: AppTheme.accentOrange,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
    );
  }
}