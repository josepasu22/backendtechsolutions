import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tareas_screen.dart';

class ProyectosScreen extends StatefulWidget {
  const ProyectosScreen({super.key});

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen> {
  final nombreController = TextEditingController();
  final descripcionController = TextEditingController();

  final proyectosRef = FirebaseFirestore.instance.collection('proyectos');
  final clientesRef = FirebaseFirestore.instance.collection('clientes');

  String? proyectoIdEditando;
  String? clienteSeleccionado;

  void guardarProyecto() async {
    if (nombreController.text.trim().isEmpty) return;

    if (proyectoIdEditando == null) {
      await proyectosRef.add({
        'nombre': nombreController.text.trim(),
        'descripcion': descripcionController.text.trim(),
        'cliente_id': clienteSeleccionado ?? '',
        'estado': 'activo',
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } else {
      await proyectosRef.doc(proyectoIdEditando).update({
        'nombre': nombreController.text.trim(),
        'descripcion': descripcionController.text.trim(),
        'cliente_id': clienteSeleccionado ?? '',
      });
      proyectoIdEditando = null;
    }

    limpiarCampos();
  }

  void editarProyecto(DocumentSnapshot proyecto) {
    nombreController.text = proyecto['nombre'];
    descripcionController.text = proyecto['descripcion'];
    clienteSeleccionado = (proyecto['cliente_id'] as String).isEmpty
        ? null
        : proyecto['cliente_id'];
    proyectoIdEditando = proyecto.id;
    setState(() {});
  }

  void eliminarProyecto(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar proyecto?"),
        content: const Text("También se eliminarán las tareas asociadas."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await proyectosRef.doc(id).delete();
    }
  }

  void limpiarCampos() {
    nombreController.clear();
    descripcionController.clear();
    clienteSeleccionado = null;
    setState(() {});
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'completado': return Colors.green;
      case 'en progreso': return Colors.orange;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proyectos"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔽 FORMULARIO
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                      labelText: "Nombre del proyecto",
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),

                // Selector de cliente
                StreamBuilder<QuerySnapshot>(
                  stream: clientesRef.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text("Cargando clientes...");
                    final clientes = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: clienteSeleccionado,
                      decoration: const InputDecoration(
                          labelText: "Cliente (opcional)",
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text("Sin asignar",
                                style: TextStyle(color: Colors.grey))),
                        ...clientes.map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c['nombre']))),
                      ],
                      onChanged: (value) =>
                          setState(() => clienteSeleccionado = value),
                    );
                  },
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: guardarProyecto,
                    child: Text(proyectoIdEditando == null
                        ? "Guardar Proyecto"
                        : "Actualizar Proyecto"),
                  ),
                ),
                if (proyectoIdEditando != null)
                  TextButton(
                    onPressed: limpiarCampos,
                    child: const Text("Cancelar edición"),
                  ),
              ],
            ),
          ),

          const Divider(),

          // 🔽 LISTADO
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: proyectosRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final proyectos = snapshot.data!.docs;

                if (proyectos.isEmpty) {
                  return const Center(child: Text("No hay proyectos creados."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: proyectos.length,
                  itemBuilder: (context, index) {
                    final proyecto = proyectos[index];
                    final sinAsignar =
                        (proyecto['cliente_id'] as String).isEmpty;
                    final estado = proyecto['estado'] ?? 'activo';

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        // 🔥 Click en la card → va a tareas del proyecto
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TareasScreen(
                              proyectoId: proyecto.id,
                              proyectoNombre: proyecto['nombre'],
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Ícono de estado
                              CircleAvatar(
                                backgroundColor:
                                    _estadoColor(estado).withOpacity(0.15),
                                child: Icon(Icons.folder,
                                    color: _estadoColor(estado)),
                              ),
                              const SizedBox(width: 12),

                              // Info del proyecto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(proyecto['nombre'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    Text(proyecto['descripcion'],
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _estadoColor(estado)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(estado,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: _estadoColor(estado),
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          sinAsignar
                                              ? "⚠️ Sin cliente"
                                              : "✅ Con cliente",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: sinAsignar
                                                  ? Colors.orange
                                                  : Colors.green),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Botones editar / eliminar
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => editarProyecto(proyecto),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () =>
                                        eliminarProyecto(context, proyecto.id),
                                  ),
                                ],
                              ),

                              // Flecha indicando que es clickeable
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}