import 'package:flutter/material.dart';

class ListaConsultas extends StatelessWidget {
  final List<Map<String, dynamic>> consultas;
  final bool loading;
  final bool hasMore;
  final VoidCallback onCargarMas;
  final VoidCallback onRefresh;

  const ListaConsultas({
    super.key,
    required this.consultas,
    required this.loading,
    required this.hasMore,
    required this.onCargarMas,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && consultas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (consultas.isEmpty) {
      return const Center(child: Text('No hay consultas registradas'));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: consultas.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == consultas.length) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextButton(
                  onPressed: onCargarMas,
                  child: const Text('Cargar más'),
                ),
              ),
            );
          }
          final c = consultas[index];
          final fechaStr = c['fecha']?.toString().split('T').first ?? 
                          c['fecha_consulta']?.toString().split('T').first ?? '';
          final especialidad = c['especialidad_nombre'] ?? c['especialidad'] ?? '';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              leading: const Icon(Icons.medical_services, color: Colors.blue),
              title: Text('${c['medico_nombre'] ?? ''} ${c['medico_apellido'] ?? ''}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fechaStr.isNotEmpty) Text('Fecha: $fechaStr'),
                  if (especialidad.isNotEmpty) Text('Especialidad: $especialidad'),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c['motivo'] != null || c['motivo_consulta'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Motivo: ${c['motivo'] ?? c['motivo_consulta'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (c['diagnostico'] != null || c['diagnostico_consulta'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.assignment, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Diagnóstico: ${c['diagnostico'] ?? c['diagnostico_consulta'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (c['observaciones'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Observaciones: ${c['observaciones']}',
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (c['sintomas'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sick, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Síntomas: ${c['sintomas']}'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
