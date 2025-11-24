import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../api.dart';

class GeneradorPdf {
  Future<void> generarYCompartirPdf({
    required List<Map<String, dynamic>> consultas,
    required List<Map<String, dynamic>> examenes,
    required List<Map<String, dynamic>> recetas,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int? medicoId,
    required BuildContext context,
  }) async {
    try {
      // Primero intenta descargar desde el backend
      final res = await ApiHistoriaClinica.descargarPdf(
        fechaDesde: fechaDesde != null ? _fmtDate(fechaDesde) : null,
        fechaHasta: fechaHasta != null ? _fmtDate(fechaHasta) : null,
        medicoId: medicoId,
      );

      if (res['ok'] == true && res['data'] != null) {
        final bytes = res['data'] as List<int>;
        
        // Usar printing para mostrar/guardar el PDF
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => Uint8List.fromList(bytes),
            name: 'Historia_Clinica.pdf',
          );
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF descargado exitosamente')),
            );
          }
        } catch (e) {
          // Si printing falla, intentar con share_plus
          if (!kIsWeb) {
            try {
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/historia_clinica.pdf');
              await file.writeAsBytes(bytes);
              
              await Share.shareXFiles(
                [XFile(file.path)],
                text: 'Mi Historia Clínica',
              );
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF descargado y compartido')),
                );
              }
            } catch (e2) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al compartir PDF: $e2')),
                );
              }
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF descargado. Usa el botón de imprimir/guardar del visor.')),
              );
            }
          }
        }
      } else {
        // Si el backend no tiene PDF, generamos uno localmente
        await _generarPdfLocal(consultas, examenes, recetas, context);
      }
    } catch (e) {
      // Si falla, intentamos generar PDF local
      try {
        await _generarPdfLocal(consultas, examenes, recetas, context);
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar PDF: $e2')),
          );
        }
      }
    }
  }

  Future<void> _generarPdfLocal(
    List<Map<String, dynamic>> consultas,
    List<Map<String, dynamic>> examenes,
    List<Map<String, dynamic>> recetas,
    BuildContext context,
  ) async {
    try {
      final user = await ApiAuth.getStoredUser();
      final paciente = '${user?['nombre'] ?? ''} ${user?['apellido'] ?? ''}'.trim();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('HISTORIA CLÍNICA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Paciente: $paciente', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 30),
              
              // Consultas
              if (consultas.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('CONSULTAS MÉDICAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                ...consultas.map((c) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Fecha: ${c['fecha']?.toString().split('T').first ?? c['fecha_consulta']?.toString().split('T').first ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Médico: ${c['medico_nombre'] ?? ''} ${c['medico_apellido'] ?? ''}'),
                      if (c['especialidad_nombre'] != null || c['especialidad'] != null) 
                        pw.Text('Especialidad: ${c['especialidad_nombre'] ?? c['especialidad'] ?? ''}'),
                      if (c['diagnostico'] != null || c['diagnostico_consulta'] != null) 
                        pw.Text('Diagnóstico: ${c['diagnostico'] ?? c['diagnostico_consulta'] ?? ''}'),
                      if (c['motivo'] != null || c['motivo_consulta'] != null) 
                        pw.Text('Motivo: ${c['motivo'] ?? c['motivo_consulta'] ?? ''}'),
                      if (c['observaciones'] != null) 
                        pw.Text('Observaciones: ${c['observaciones']}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                      if (c['sintomas'] != null) 
                        pw.Text('Síntomas: ${c['sintomas']}'),
                    ],
                  ),
                )),
                pw.SizedBox(height: 20),
              ],

              // Exámenes
              if (examenes.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('EXÁMENES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                ...examenes.map((e) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Tipo: ${e['tipo_examen'] ?? e['nombre'] ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Fecha: ${e['fecha']?.toString().split('T').first ?? e['fecha_examen']?.toString().split('T').first ?? 'N/A'}'),
                      if (e['medico_nombre'] != null) 
                        pw.Text('Médico: ${e['medico_nombre']} ${e['medico_apellido'] ?? ''}'),
                      if (e['resultado'] != null || e['resultados'] != null) 
                        pw.Text('Resultado: ${e['resultado'] ?? e['resultados'] ?? ''}'),
                      if (e['laboratorio'] != null) 
                        pw.Text('Laboratorio: ${e['laboratorio']}'),
                      if (e['observaciones'] != null) 
                        pw.Text('Observaciones: ${e['observaciones']}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                      if (e['estado'] != null) 
                        pw.Text('Estado: ${e['estado']}'),
                    ],
                  ),
                )),
                pw.SizedBox(height: 20),
              ],

              // Recetas
              if (recetas.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('RECETAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                ...recetas.map((r) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Fecha: ${r['fecha']?.toString().split('T').first ?? r['fecha_receta']?.toString().split('T').first ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (r['medico_nombre'] != null) 
                        pw.Text('Médico: ${r['medico_nombre']} ${r['medico_apellido'] ?? ''}'),
                      if (r['medicamentos'] != null || r['medicamento'] != null) 
                        pw.Text('Medicamentos: ${r['medicamentos'] ?? r['medicamento'] ?? ''}'),
                      if (r['indicaciones'] != null || r['instrucciones'] != null) 
                        pw.Text('Indicaciones: ${r['indicaciones'] ?? r['instrucciones'] ?? ''}'),
                      if (r['dosis'] != null) 
                        pw.Text('Dosis: ${r['dosis']}'),
                      if (r['duracion'] != null) 
                        pw.Text('Duración: ${r['duracion']}'),
                      if (r['observaciones'] != null) 
                        pw.Text('Observaciones: ${r['observaciones']}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                )),
              ],
            ];
          },
        ),
      );

      // Guardar y compartir usando printing (funciona en todas las plataformas)
      final bytes = await pdf.save();
      final pdfBytes = Uint8List.fromList(bytes);
      
      // Intentar compartir directamente usando printing
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Historia_Clinica_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generado exitosamente')),
          );
        }
      } catch (e) {
        // Si printing falla, intentar con share_plus
        try {
          if (!kIsWeb) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/historia_clinica_${DateTime.now().millisecondsSinceEpoch}.pdf');
            await file.writeAsBytes(bytes);
            
            await Share.shareXFiles(
              [XFile(file.path)],
              text: 'Mi Historia Clínica',
            );
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF generado y compartido')),
              );
            }
          } else {
            // En web, usar printing directamente
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdfBytes,
            );
          }
        } catch (e2) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al compartir PDF: $e2')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
