import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TareasScreen extends StatefulWidget {
  final String proyectoId;
  final String proyectoNombre;

  const TareasScreen({
    super.key,
    required this.proyectoId,
    required this.proyectoNombre,
  });

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  final nombreController = TextEditingController();
  final tareasRef = FirebaseFirestore.instance.collection('tareas');
  final usuariosRef = FirebaseFirestore.instance.collection('usuarios');

  String? tareaIdEditando;
  String? trabajadorSeleccionado;
  String prioridad = "media";
  String estado = "pendiente";

  void guardarTarea() async {
    if (nombreController.text.trim().isEmpty) return;

    final datos = {
      'nombre': nombreController.text.trim(),
      'proyecto_id': widget.proyectoId,
      'prioridad': prioridad,
      'estado': estado,
      'trabajador_uid': trabajadorSeleccionado ?? '',
    };

    if (tareaIdEditando == null) {
      await tareasRef.add(datos);
    } else {
      await tareasRef.doc(tareaIdEditando).update(datos);
      tareaIdEditando = null;
    }

    limpiarCampos();
  }

  void editarTarea(DocumentSnapshot tarea) {
    nombreController.text = tarea['nombre'];
    prioridad = tarea['prioridad'];
    estado = tarea['estado'];
    final tw = (tarea.data() as Map)['trabajador_uid'] ?? '';
    trabajadorSeleccionado = tw.isEmpty ? null : tw;
    tareaIdEditando = tarea.id;
    setState(() {});
  }

  void eliminarTarea(String id) async {
    await tareasRef.doc(id).delete();
    // Recalcula estado del proyecto
    _recalcularEstadoProyecto();
  }

  Future<void> _recalcularEstadoProyecto() async {
    final tareasSnap = await tareasRef
        .where('proyecto_id', isEqualTo: widget.proyectoId)
        .get();

    final total = tareasSnap.docs.length;
    final completadas =
        tareasSnap.docs.where((t) => t['estado'] == 'completada').length;

    String nuevoEstado;
    if (total == 0 || completadas == 0) {
      nuevoEstado = 'activo';
    } else if (completadas == total) {
      nuevoEstado = 'completado';
    } else {
      nuevoEstado = 'en progreso';
    }

    await FirebaseFirestore.instance
        .collection('proyectos')
        .doc(widget.proyectoId)
        .update({'estado': nuevoEstado});
  }

  void limpiarCampos() {
    nombreController.clear();
    trabajadorSeleccionado = null;
    prioridad = "media";
    estado = "pendiente";
    setState(() {});
  }

  Color _prioridadColor(String p) {
    switch (p) {
      case 'alta': return Colors.red;
      case 'media': return Colors.orange;
      default: return Colors.green;
    }
  }

  Color _estadoColor(String e) {
    switch (e) {
      case 'completada': return Colors.green;
      case 'en progreso': return Colors.orange;
      default: return Colors.grey;
    }
  }

  void _mostrarFormulario(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tareaIdEditando == null ? "Nueva Tarea" : "Editar Tarea",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                    labelText: "Nombre de la tarea",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),

              // Selector de trabajador
              StreamBuilder<QuerySnapshot>(
                stream: usuariosRef.where('rol', isEqualTo: 'trabajador').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text("Cargando...");
                  final trabajadores = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: trabajadorSeleccionado,
                    decoration: const InputDecoration(
                        labelText: "Asignar trabajador",
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text("Sin asignar",
                              style: TextStyle(color: Colors.grey))),
                      ...trabajadores.map((t) {
                        final data = t.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: t.id,
                          child: Text(data['nombre'] ?? data['correo'] ?? t.id),
                        );
                      }),
                    ],
                    onChanged: (value) =>
                        setModalState(() => trabajadorSeleccionado = value),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Prioridad
              DropdownButtonFormField<String>(
                value: prioridad,
                decoration: const InputDecoration(
                    labelText: "Prioridad", border: OutlineInputBorder()),
                items: ["alta", "media", "baja"]
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (value) => setModalState(() => prioridad = value!),
              ),
              const SizedBox(height: 8),

              // Estado
              DropdownButtonFormField<String>(
                value: estado,
                decoration: const InputDecoration(
                    labelText: "Estado", border: OutlineInputBorder()),
                items: ["pendiente", "en progreso", "completada"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setModalState(() => estado = value!),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  if (tareaIdEditando != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          limpiarCampos();
                          Navigator.pop(ctx);
                        },
                        child: const Text("Cancelar"),
                      ),
                    ),
                  if (tareaIdEditando != null) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        guardarTarea();
                        _recalcularEstadoProyecto();
                        Navigator.pop(ctx);
                      },
                      child: Text(tareaIdEditando == null
                          ? "Guardar"
                          : "Actualizar"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 🔥 Botón de regreso
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tareas", style: TextStyle(fontSize: 16)),
            Text(widget.proyectoNombre,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),

      // 🔥 FAB para agregar tarea
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          limpiarCampos();
          _mostrarFormulario(context);
        },
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: tareasRef
            .where('proyecto_id', isEqualTo: widget.proyectoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tareas = snapshot.data!.docs;

          if (tareas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.task_alt, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text("No hay tareas en este proyecto.",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarFormulario(context),
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar primera tarea"),
                  ),
                ],
              ),
            );
          }

          // Barra de progreso general
          final total = tareas.length;
          final completadas =
              tareas.where((t) => t['estado'] == 'completada').length;
          final progreso = total == 0 ? 0.0 : completadas / total;

          return Column(
            children: [
              // 🔥 Barra de progreso del proyecto
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Progreso del proyecto",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${(progreso * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progreso,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        color: progreso == 1.0 ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("$completadas de $total tareas completadas",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

              // 🔥 Lista de tareas
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tareas.length,
                  itemBuilder: (context, index) {
                    final tarea = tareas[index];
                    final estadoTarea = tarea['estado'] ?? 'pendiente';
                    final prio = tarea['prioridad'] ?? 'media';
                    final tieneTrabajador =
                        ((tarea.data() as Map)['trabajador_uid'] ?? '').isNotEmpty;

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(
                          estadoTarea == 'completada'
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _estadoColor(estadoTarea),
                        ),
                        title: Text(
                          tarea['nombre'],
                          style: TextStyle(
                            decoration: estadoTarea == 'completada'
                                ? TextDecoration.lineThrough
                                : null,
                            color: estadoTarea == 'completada'
                                ? Colors.grey
                                : null,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    _prioridadColor(prio).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(prio,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _prioridadColor(prio),
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              tieneTrabajador
                                  ? Icons.engineering
                                  : Icons.person_outline,
                              size: 14,
                              color: tieneTrabajador
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tieneTrabajador ? "Asignada" : "Sin asignar",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: tieneTrabajador
                                      ? Colors.orange
                                      : Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blue, size: 20),
                              onPressed: () {
                                editarTarea(tarea);
                                _mostrarFormulario(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () => eliminarTarea(tarea.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}