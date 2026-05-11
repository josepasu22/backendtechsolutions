import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrabajadorScreen extends StatelessWidget {
  final String uid;
  const TrabajadorScreen({super.key, required this.uid});

  Color _prioridadColor(String prioridad) {
    switch (prioridad) {
      case 'alta': return Colors.red;
      case 'media': return Colors.orange;
      default: return Colors.green;
    }
  }

  // 🔥 Marca tarea como completada y actualiza progreso del proyecto
  Future<void> completarTarea(String tareaId, String proyectoId) async {
    await FirebaseFirestore.instance.collection('tareas').doc(tareaId).update({
      'estado': 'completada',
    });

    // Recalcula el estado del proyecto automáticamente
    final tareasSnap = await FirebaseFirestore.instance
        .collection('tareas')
        .where('proyecto_id', isEqualTo: proyectoId)
        .get();

    final total = tareasSnap.docs.length;
    final completadas = tareasSnap.docs.where((t) => t['estado'] == 'completada').length;

    String nuevoEstado;
    if (completadas == total && total > 0) {
      nuevoEstado = 'completado';
    } else if (completadas > 0) {
      nuevoEstado = 'en progreso';
    } else {
      nuevoEstado = 'activo';
    }

    await FirebaseFirestore.instance.collection('proyectos').doc(proyectoId).update({
      'estado': nuevoEstado,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Tareas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 Solo tareas asignadas a este trabajador
        stream: FirebaseFirestore.instance
            .collection('tareas')
            .where('trabajador_uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final tareas = snapshot.data!.docs;

          if (tareas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      "No tienes tareas asignadas aún.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          // Separa pendientes/en progreso de completadas
          final activas = tareas.where((t) => t['estado'] != 'completada').toList();
          final completadas = tareas.where((t) => t['estado'] == 'completada').toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (activas.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("PENDIENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                ),
                ...activas.map((tarea) => _TareaCard(
                      tarea: tarea,
                      onCompletar: () => completarTarea(tarea.id, tarea['proyecto_id']),
                      prioridadColor: _prioridadColor(tarea['prioridad'] ?? 'baja'),
                    )),
              ],
              if (completadas.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("COMPLETADAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                ),
                ...completadas.map((tarea) => _TareaCard(
                      tarea: tarea,
                      onCompletar: null, // ya completada
                      prioridadColor: Colors.grey,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TareaCard extends StatelessWidget {
  final DocumentSnapshot tarea;
  final VoidCallback? onCompletar;
  final Color prioridadColor;

  const _TareaCard({
    required this.tarea,
    required this.onCompletar,
    required this.prioridadColor,
  });

  @override
  Widget build(BuildContext context) {
    final completada = tarea['estado'] == 'completada';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          completada ? Icons.check_circle : Icons.radio_button_unchecked,
          color: completada ? Colors.green : Colors.grey,
          size: 28,
        ),
        title: Text(
          tarea['nombre'],
          style: TextStyle(
            decoration: completada ? TextDecoration.lineThrough : null,
            color: completada ? Colors.grey : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: prioridadColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tarea['prioridad'] ?? 'media',
                style: TextStyle(fontSize: 11, color: prioridadColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(tarea['estado'] ?? 'pendiente', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: completada
            ? const Icon(Icons.verified, color: Colors.green)
            : ElevatedButton(
                onPressed: onCompletar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Completar", style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
      ),
    );
  }
}