import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class ClienteScreen extends StatelessWidget {
  final String uid;
  const ClienteScreen({super.key, required this.uid});

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'completada': return Colors.green;
      case 'en progreso': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'completada': return Icons.check_circle;
      case 'en progreso': return Icons.timelapse;
      default: return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Proyectos"),
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
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(uid).get(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final data = userSnap.data!.data() as Map<String, dynamic>?;
          final clienteId = data?['cliente_id'] ?? '';

          if (clienteId.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      "Tu cuenta aún no tiene proyectos asignados.\nContacta al administrador.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('proyectos')
                .where('cliente_id', isEqualTo: clienteId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final proyectos = snapshot.data!.docs;
              if (proyectos.isEmpty) {
                return const Center(child: Text("No tienes proyectos asignados aún."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: proyectos.length,
                itemBuilder: (context, index) {
                  final proyecto = proyectos[index];

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: const Icon(Icons.folder, color: Colors.blue),
                      title: Text(proyecto['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Estado: ${proyecto['estado']}"),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('tareas')
                              .where('proyecto_id', isEqualTo: proyecto.id)
                              .snapshots(),
                          builder: (context, tareaSnap) {
                            if (!tareaSnap.hasData) {
                              return const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator());
                            }

                            final tareas = tareaSnap.data!.docs;
                            final total = tareas.length;
                            final completadas = tareas
                                .where((t) => t['estado'] == 'completada')
                                .length;
                            final enProgreso = tareas
                                .where((t) => t['estado'] == 'en progreso')
                                .length;
                            final pendientes = tareas
                                .where((t) => t['estado'] == 'pendiente')
                                .length;
                            final progreso =
                                total == 0 ? 0.0 : completadas / total;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // 🔥 GRÁFICO DE PASTEL
                                  if (total > 0) ...[
                                    const Text("Distribución de tareas",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 180,
                                      child: Row(
                                        children: [
                                          // Pie chart
                                          Expanded(
                                            child: PieChart(
                                              PieChartData(
                                                sectionsSpace: 2,
                                                centerSpaceRadius: 36,
                                                sections: [
                                                  if (completadas > 0)
                                                    PieChartSectionData(
                                                      value: completadas.toDouble(),
                                                      color: Colors.green,
                                                      title: '$completadas',
                                                      radius: 50,
                                                      titleStyle: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white),
                                                    ),
                                                  if (enProgreso > 0)
                                                    PieChartSectionData(
                                                      value: enProgreso.toDouble(),
                                                      color: Colors.orange,
                                                      title: '$enProgreso',
                                                      radius: 50,
                                                      titleStyle: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white),
                                                    ),
                                                  if (pendientes > 0)
                                                    PieChartSectionData(
                                                      value: pendientes.toDouble(),
                                                      color: Colors.grey,
                                                      title: '$pendientes',
                                                      radius: 50,
                                                      titleStyle: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Leyenda
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _LeyendaItem(color: Colors.green, label: "Completadas", cantidad: completadas),
                                              const SizedBox(height: 8),
                                              _LeyendaItem(color: Colors.orange, label: "En progreso", cantidad: enProgreso),
                                              const SizedBox(height: 8),
                                              _LeyendaItem(color: Colors.grey, label: "Pendientes", cantidad: pendientes),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 24),
                                  ],

                                  // 🔥 BARRA DE PROGRESO
                                  Row(children: [
                                    const Text("Progreso general: ",
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text("${(progreso * 100).toStringAsFixed(0)}%"),
                                  ]),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progreso,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey[200],
                                      color: progreso == 1.0
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$completadas de $total tareas completadas",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  const Divider(height: 20),

                                  // 🔥 LISTA DE TAREAS (solo lectura)
                                  if (tareas.isEmpty)
                                    const Text("No hay tareas en este proyecto.")
                                  else
                                    ...tareas.map((t) {
                                      final estadoTarea = t['estado'] ?? 'pendiente';
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(_estadoIcon(estadoTarea),
                                            color: _estadoColor(estadoTarea)),
                                        title: Text(t['nombre']),
                                        subtitle: Text(
                                            "Prioridad: ${t['prioridad'] ?? '-'}",
                                            style: const TextStyle(fontSize: 12)),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _estadoColor(estadoTarea)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(estadoTarea,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: _estadoColor(estadoTarea),
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// 🔥 Widget de leyenda del gráfico
class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final int cantidad;

  const _LeyendaItem({
    required this.color,
    required this.label,
    required this.cantidad,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          "$label ($cantidad)",
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}