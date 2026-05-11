import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool _generando = false;

  // ── Helpers de celdas ──
  static pw.Widget _cellHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  static pw.Widget _cellEstado(String estado) {
    final color = estado == 'completada'
        ? PdfColors.green800
        : estado == 'en progreso'
            ? PdfColors.orange800
            : PdfColors.grey700;
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(estado, style: pw.TextStyle(fontSize: 9, color: color)),
    );
  }

  static pw.Widget _buildResumenItem(String label, String valor, PdfColor color) =>
      pw.Column(children: [
        pw.Text(valor,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ]);

  static pw.Widget _infoRow(String label, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(valor, style: const pw.TextStyle(fontSize: 10)),
        ]),
      );

  // 🔥 Barra de progreso para PDF usando Stack
  static pw.Widget _barraProgreso(double progreso) => pw.Stack(
        children: [
          pw.Container(
            height: 8,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
          ),
          pw.Container(
            height: 8,
            width: 400 * progreso,
            decoration: pw.BoxDecoration(
              color: progreso >= 1.0 ? PdfColors.green : PdfColors.blue,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
          ),
        ],
      );

  // 🔥 REPORTE COMPLETO
  Future<void> generarReporteCompleto() async {
    setState(() => _generando = true);
    try {
      final proyectosSnap =
          await FirebaseFirestore.instance.collection('proyectos').get();
      final clientesSnap =
          await FirebaseFirestore.instance.collection('clientes').get();
      final tareasSnap =
          await FirebaseFirestore.instance.collection('tareas').get();
      final usuariosSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'trabajador')
          .get();

      final clientesMap = {for (var c in clientesSnap.docs) c.id: c['nombre'] as String};
      final trabajadoresMap = {
        for (var u in usuariosSnap.docs)
          u.id: ((u.data())['nombre'] ?? (u.data())['correo'] ?? 'Sin nombre') as String
      };

      final pdf = pw.Document();
      final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final totalProyectos = proyectosSnap.docs.length;
      final totalTareas = tareasSnap.docs.length;
      final completadasTotal = tareasSnap.docs.where((t) => t['estado'] == 'completada').length;
      final enProgresoTotal = tareasSnap.docs.where((t) => t['estado'] == 'en progreso').length;
      final pendientesTotal = tareasSnap.docs.where((t) => t['estado'] == 'pendiente').length;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TechSolutions S.A.',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generado: $fecha',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ]),
          pw.Text('Reporte General de Proyectos y Tareas',
              style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
          pw.Divider(color: PdfColors.blue),
          pw.SizedBox(height: 4),
        ]),
        footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TechSolutions S.A. — Reporte Confidencial',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ]),
        build: (_) {
          final widgets = <pw.Widget>[];

          // Resumen
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Resumen General',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                _buildResumenItem('Proyectos', totalProyectos.toString(), PdfColors.blue),
                _buildResumenItem('Total tareas', totalTareas.toString(), PdfColors.grey700),
                _buildResumenItem('Completadas', completadasTotal.toString(), PdfColors.green),
                _buildResumenItem('En progreso', enProgresoTotal.toString(), PdfColors.orange),
                _buildResumenItem('Pendientes', pendientesTotal.toString(), PdfColors.red),
              ]),
            ]),
          ));
          widgets.add(pw.SizedBox(height: 20));
          widgets.add(pw.Text('Detalle por Proyecto',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 10));

          for (final proyecto in proyectosSnap.docs) {
            final pData = proyecto.data();
            final clienteNombre = clientesMap[pData['cliente_id']] ?? 'Sin cliente';
            final estado = pData['estado'] ?? 'activo';
            final tareasProy = tareasSnap.docs.where((t) => t['proyecto_id'] == proyecto.id).toList();
            final totalProy = tareasProy.length;
            final compProy = tareasProy.where((t) => t['estado'] == 'completada').length;
            final progreso = totalProy == 0 ? 0.0 : compProy / totalProy;
            final estadoColor = estado == 'completado'
                ? PdfColors.green
                : estado == 'en progreso'
                    ? PdfColors.orange
                    : PdfColors.blue;

            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(6),
                      topRight: pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Expanded(
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(pData['nombre'] ?? '',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Cliente: $clienteNombre',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        if ((pData['descripcion'] ?? '').isNotEmpty)
                          pw.Text(pData['descripcion'],
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                      ]),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: estadoColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(estado,
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    ),
                  ]),
                ),
                // Progreso y tareas
                pw.Padding(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Progreso: $compProy/$totalProy tareas completadas',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('${(progreso * 100).toStringAsFixed(0)}%',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 4),
                    _barraProgreso(progreso),
                    if (tareasProy.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(3),
                          1: const pw.FlexColumnWidth(1.5),
                          2: const pw.FlexColumnWidth(1.5),
                          3: const pw.FlexColumnWidth(2),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _cellHeader('Tarea'),
                              _cellHeader('Estado'),
                              _cellHeader('Prioridad'),
                              _cellHeader('Trabajador'),
                            ],
                          ),
                          ...tareasProy.map((t) {
                            final tData = t.data() as Map<String, dynamic>;
                            return pw.TableRow(children: [
                              _cell(tData['nombre'] ?? ''),
                              _cellEstado(tData['estado'] ?? 'pendiente'),
                              _cell(tData['prioridad'] ?? 'media'),
                              _cell(trabajadoresMap[tData['trabajador_uid']] ?? 'Sin asignar'),
                            ]);
                          }),
                        ],
                      ),
                    ] else ...[
                      pw.SizedBox(height: 8),
                      pw.Text('Sin tareas registradas.',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    ],
                  ]),
                ),
              ]),
            ));
          }

          return widgets;
        },
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'Reporte_TechSolutions_$fecha.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  // 🔥 REPORTE POR PROYECTO
  Future<void> generarReporteProyecto(
      Map<String, dynamic> pData, String proyectoId, String clienteNombre) async {
    setState(() => _generando = true);
    try {
      final tareasSnap = await FirebaseFirestore.instance
          .collection('tareas')
          .where('proyecto_id', isEqualTo: proyectoId)
          .get();
      final usuariosSnap =
          await FirebaseFirestore.instance.collection('usuarios').get();
      final trabajadoresMap = {
        for (var u in usuariosSnap.docs)
          u.id: ((u.data())['nombre'] ?? (u.data())['correo'] ?? 'Sin nombre') as String
      };

      final pdf = pw.Document();
      final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final tareas = tareasSnap.docs;
      final total = tareas.length;
      final completadas = tareas.where((t) => t['estado'] == 'completada').length;
      final progreso = total == 0 ? 0.0 : completadas / total;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TechSolutions S.A.',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Fecha: $fecha',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ]),
          pw.Text('Reporte de Proyecto: ${pData['nombre']}',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Divider(color: PdfColors.blue),
        ]),
        footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Confidencial',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          pw.Text('Pág. ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ]),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Información del Proyecto',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _infoRow('Cliente', clienteNombre),
              _infoRow('Estado', pData['estado'] ?? 'activo'),
              _infoRow('Descripción', pData['descripcion'] ?? '-'),
              _infoRow('Progreso',
                  '${(progreso * 100).toStringAsFixed(0)}% ($completadas/$total tareas)'),
            ]),
          ),
          pw.SizedBox(height: 8),
          _barraProgreso(progreso),
          pw.SizedBox(height: 16),
          pw.Text('Tareas del Proyecto',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (tareas.isEmpty)
            pw.Text('Sin tareas registradas.',
                style: const pw.TextStyle(color: PdfColors.grey))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cellHeader('Tarea'),
                    _cellHeader('Estado'),
                    _cellHeader('Prioridad'),
                    _cellHeader('Trabajador'),
                  ],
                ),
                ...tareas.map((t) {
                  final tData = t.data() as Map<String, dynamic>;
                  return pw.TableRow(children: [
                    _cell(tData['nombre'] ?? ''),
                    _cellEstado(tData['estado'] ?? 'pendiente'),
                    _cell(tData['prioridad'] ?? 'media'),
                    _cell(trabajadoresMap[tData['trabajador_uid']] ?? 'Sin asignar'),
                  ]);
                }),
              ],
            ),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'Reporte_${pData['nombre']}_$fecha.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Reportes"),
      ),
      body: _generando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("Generando reporte PDF..."),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Reporte general
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(Icons.picture_as_pdf, color: Colors.blue),
                    ),
                    title: const Text("Reporte General",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        "Todos los proyectos y tareas con progreso y trabajadores"),
                    trailing: ElevatedButton.icon(
                      onPressed: generarReporteCompleto,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text("Generar"),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("REPORTE POR PROYECTO",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),

                // Lista de proyectos
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('proyectos')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final proyectos = snapshot.data!.docs;
                    if (proyectos.isEmpty) {
                      return const Center(
                          child: Text("No hay proyectos registrados."));
                    }

                    return Column(
                      children: proyectos.map((proyecto) {
                        final pData = proyecto.data() as Map<String, dynamic>;
                        final estado = pData['estado'] ?? 'activo';
                        final clienteId = (pData['cliente_id'] ?? '') as String;
                        final color = estado == 'completado'
                            ? Colors.green
                            : estado == 'en progreso'
                                ? Colors.orange
                                : Colors.blue;

                        return FutureBuilder<DocumentSnapshot?>(
                          future: clienteId.isNotEmpty
                              ? FirebaseFirestore.instance
                                  .collection('clientes')
                                  .doc(clienteId)
                                  .get()
                              : Future.value(null),
                          builder: (context, clienteSnap) {
                            String clienteNombre = 'Sin cliente';
                            if (clienteSnap.hasData && clienteSnap.data != null) {
                              final d = clienteSnap.data!.data()
                                  as Map<String, dynamic>?;
                              clienteNombre = d?['nombre'] ?? 'Sin cliente';
                            }

                            return Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Icon(Icons.folder, color: color),
                                ),
                                title: Text(pData['nombre'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Cliente: $clienteNombre  •  Estado: $estado'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.picture_as_pdf,
                                      color: Colors.red),
                                  tooltip: "Generar PDF",
                                  onPressed: () => generarReporteProyecto(
                                      pData, proyecto.id, clienteNombre),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}