import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'proyectos_screen.dart';
import 'reportes_screen.dart';

class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  void cambiarRol(BuildContext context, String uid, String rolActual) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cambiar rol"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['cliente', 'trabajador', 'admin'].map((rol) {
            return ListTile(
              leading: Icon(
                rol == rolActual ? Icons.radio_button_checked : Icons.radio_button_off,
                color: rol == rolActual ? Colors.blue : Colors.grey,
              ),
              title: Text(rol[0].toUpperCase() + rol.substring(1)),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(uid)
                    .update({'rol': rol});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void eliminarUsuario(BuildContext context, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar usuario?"),
        content: const Text("Esto eliminará el registro del usuario en el sistema."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).delete();
    }
  }

  Color _rolColor(String rol) {
    switch (rol) {
      case 'admin': return Colors.red;
      case 'trabajador': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _rolIcon(String rol) {
    switch (rol) {
      case 'admin': return Icons.admin_panel_settings;
      case 'trabajador': return Icons.engineering;
      default: return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Usuarios"),
        actions: [
          // 🆕 Botón de reportes
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Reportes",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReportesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: "Proyectos",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProyectosScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final usuarios = snapshot.data!.docs;
          if (usuarios.isEmpty) return const Center(child: Text("No hay usuarios registrados."));

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              final data = usuario.data() as Map<String, dynamic>;
              final rol = data['rol'] ?? 'cliente';
              final correo = data['correo'] ?? '';
              final nombre = data['nombre'] ?? correo;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _rolColor(rol).withOpacity(0.15),
                    child: Icon(_rolIcon(rol), color: _rolColor(rol)),
                  ),
                  title: Text(nombre),
                  subtitle: Text(correo),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => cambiarRol(context, usuario.id, rol),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _rolColor(rol).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _rolColor(rol)),
                          ),
                          child: Text(
                            rol[0].toUpperCase() + rol.substring(1),
                            style: TextStyle(
                                color: _rolColor(rol),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => eliminarUsuario(context, usuario.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}