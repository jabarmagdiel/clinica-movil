import 'package:flutter/material.dart';

class ListaExamenes extends StatelessWidget {
  final List<Map<String, dynamic>> examenes;
  final bool loading;
  final bool hasMore;
  final VoidCallback onCargarMas;
  final VoidCallback onRefresh;

  const ListaExamenes({
    super.key,
    required this.examenes,
    required this.loading,
    required this.hasMore,
    required this.onCargarMas,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && examenes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (examenes.isEmpty) {
      return const Center(child: Text('No hay exámenes registrados'));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: examenes.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == examenes.length) {
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
          final e = examenes[index];
          final fechaStr = e['fecha']?.toString().split('T').first ?? 
                          e['fecha_examen']?.toString().split('T').first ?? '';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              leading: const Icon(Icons.science, color: Colors.green),
              title: Text(e['tipo_examen'] ?? e['nombre'] ?? 'Examen'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fechaStr.isNotEmpty) Text('Fecha: $fechaStr'),
                  if (e['medico_nombre'] != null)
                    Text('Médico: ${e['medico_nombre']} ${e['medico_apellido'] ?? ''}'),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e['resultado'] != null || e['resultados'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.assessment, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Resultado: ${e['resultado'] ?? e['resultados'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (e['observaciones'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Observaciones: ${e['observaciones']}',
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (e['laboratorio'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.local_hospital, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Laboratorio: ${e['laboratorio']}'),
                              ),
                            ],
                          ),
                        ),
                      if (e['estado'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.info, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Estado: ${e['estado']}',
                                style: TextStyle(
                                  color: e['estado'].toString().toLowerCase() == 'completado' 
                                      ? Colors.green 
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
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
