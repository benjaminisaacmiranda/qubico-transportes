import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart' as app_models;
import '../../providers/user_provider.dart';
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

  Color _roleColor(String rol) {
    switch (rol) {
      case 'conductor':
        return AppTheme.accentOrange;
      case 'admin':
        return AppTheme.primaryBlue;
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String rol) {
    switch (rol) {
      case 'conductor':
        return 'Conductor';
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuario';
    }
  }

  Widget _buildAccountsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No hay usuarios registrados',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Presiona + para agregar el primero',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final data = doc.data() as Map<String, dynamic>;
            final rol = data['rol'] as String? ?? 'usuario';
            final isActive = data['isActive'] as bool? ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              child: ListTile(
                onTap: () => _showEditUserDialog(doc.id, data),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: _roleColor(rol).withOpacity(0.15),
                  child: Icon(_roleIcon(rol), color: _roleColor(rol), size: 22),
                ),
                title: Text(
                  data['fullName'] ?? 'Sin nombre',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  data['correo'] ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor(rol).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleLabel(rol),
                        style: TextStyle(
                          color: _roleColor(rol),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.history, color: AppTheme.primaryBlue),
            title: const Text('Auditoría del Sistema'),
            subtitle: const Text(
              'Sistema de auditoría activo (pendiente integración real)',
            ),
          ),
        ),
      ],
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final rutController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePass = true;
    bool isSaving = false;
    String selectedRole = 'conductor';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 8),
              const Text('Nuevo Usuario'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: rutController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9kK]')),
                        LengthLimitingTextInputFormatter(9),
                      ],
                      onChanged: (value) {
                        final limpio = value.replaceAll('-', '');

                        if (limpio.length >= 2) {
                          final nuevo =
                              '${limpio.substring(0, limpio.length - 1)}-${limpio.substring(limpio.length - 1)}';

                          if (nuevo != rutController.text) {
                            rutController.value = TextEditingValue(
                              text: nuevo,
                              selection: TextSelection.collapsed(
                                offset: nuevo.length,
                              ),
                            );
                          }
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'RUT',
                        hintText: '12345678-5',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese un RUT';
                        }

                        final rut = value.trim().toUpperCase();

                        if (!rut.contains('-')) {
                          return 'El RUT debe incluir guion';
                        }

                        final partes = rut.split('-');

                        if (partes.length != 2) {
                          return 'Formato inválido';
                        }

                        final cuerpo = partes[0];
                        final dvIngresado = partes[1];

                        if (cuerpo.length < 7 || cuerpo.length > 8) {
                          return 'RUT inválido';
                        }

                        int suma = 0;
                        int multiplicador = 2;

                        for (int i = cuerpo.length - 1; i >= 0; i--) {
                          suma += int.parse(cuerpo[i]) * multiplicador;
                          multiplicador = multiplicador == 7
                              ? 2
                              : multiplicador + 1;
                        }

                        final resto = 11 - (suma % 11);

                        String dvCorrecto;

                        if (resto == 11) {
                          dvCorrecto = '0';
                        } else if (resto == 10) {
                          dvCorrecto = 'K';
                        } else {
                          dvCorrecto = resto.toString();
                        }

                        if (dvIngresado != dvCorrecto) {
                          return 'RUT no válido';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          Validators.validateRequired(v, 'El nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese un correo valido';
                        }

                        final regex = RegExp(
                          r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$',
                        );

                        if (!regex.hasMatch(value.trim())) {
                          return 'Correo inválido';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Teléfono celular',
                        hintText: '912345678',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingrese un teléfono';
                        }

                        if (v.length != 9) {
                          return 'Debe tener 9 dígitos';
                        }

                        if (!v.startsWith('9')) {
                          return 'Debe comenzar con 9';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscurePass = !obscurePass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: Icon(Icons.manage_accounts_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'conductor',
                          child: Row(
                            children: [
                              Icon(
                                Icons.drive_eta,
                                size: 18,
                                color: AppTheme.accentOrange,
                              ),
                              SizedBox(width: 8),
                              Text('CONDUCTOR'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              SizedBox(width: 8),
                              Text('ADMINISTRADOR'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'usuario',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('USUARIO'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => selectedRole = v!),
                    ),
                    if (selectedRole == 'conductor') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentOrange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppTheme.accentOrange,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Este conductor podrá ser asignado en Gestión de Flota.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(isSaving ? 'Guardando…' : 'GUARDAR'),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      try {
                        final cred = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );
                        final uid = cred.user!.uid;
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .set({
                              'correo': emailController.text.trim(),
                              'fullName': nameController.text.trim(),
                              'rut': rutController.text.trim(),
                              'telefono': phoneController.text.trim(),
                              'rol': selectedRole,
                              'isActive': true,
                            });
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
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedRole == 'conductor'
                                        ? 'Conductor creado. Ya aparece en Gestión de Flota.'
                                        : 'Usuario creado exitosamente.',
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
                              content: Text(e.message ?? 'Error de Firebase'),
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
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(String uid, Map<String, dynamic> data) {
    String selectedRole = data['rol'] as String? ?? 'usuario';
    bool isActive = data['isActive'] as bool? ?? false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 8),
              const Text('Editar Usuario'),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['fullName'] ?? 'Sin nombre',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  data['correo'] ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'conductor',
                      child: Row(
                        children: [
                          Icon(
                            Icons.drive_eta,
                            size: 18,
                            color: AppTheme.accentOrange,
                          ),
                          SizedBox(width: 8),
                          Text('CONDUCTOR'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 18,
                            color: AppTheme.primaryBlue,
                          ),
                          SizedBox(width: 8),
                          Text('ADMINISTRADOR'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'usuario',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('USUARIO'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cuenta activa'),
                  subtitle: Text(
                    isActive
                        ? 'El usuario puede iniciar sesión'
                        : 'Acceso bloqueado',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                  value: isActive,
                  activeColor: Colors.green,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(isSaving ? 'Guardando…' : 'GUARDAR'),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({
                              'rol': selectedRole,
                              'isActive': isActive,
                            });

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Usuario actualizado correctamente.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al actualizar: $e'),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

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
        children: [_buildAccountsTab(), _buildAuditTab()],
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
