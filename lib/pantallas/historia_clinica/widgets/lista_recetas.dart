import 'package:flutter/material.dart';

class ListaRecetas extends StatelessWidget {
  final List<Map<String, dynamic>> recetas;
  final bool loading;
  final bool hasMore;
  final VoidCallback onCargarMas;
  final VoidCallback onRefresh;

  const ListaRecetas({
    super.key,
    required this.recetas,
    required this.loading,
    required this.hasMore,
    required this.onCargarMas,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && recetas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recetas.isEmpty) {
      return const Center(child: Text('No hay recetas registradas'));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: recetas.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == recetas.length) {
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
          final r = recetas[index];
          final fechaStr = r['fecha']?.toString().split('T').first ?? 
                          r['fecha_receta']?.toString().split('T').first ?? '';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              leading: const Icon(Icons.medication, color: Colors.orange),
              title: Text('Receta${fechaStr.isNotEmpty ? ' del $fechaStr' : ''}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r['medico_nombre'] != null)
                    Text('Médico: ${r['medico_nombre']} ${r['medico_apellido'] ?? ''}'),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r['medicamentos'] != null || r['medicamento'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.medication_liquid, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Medicamentos: ${r['medicamentos'] ?? r['medicamento'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (r['indicaciones'] != null || r['instrucciones'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.assignment, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Indicaciones: ${r['indicaciones'] ?? r['instrucciones'] ?? ''}',
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (r['dosis'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.science, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Dosis: ${r['dosis']}'),
                              ),
                            ],
                          ),
                        ),
                      if (r['duracion'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Duración: ${r['duracion']}'),
                              ),
                            ],
                          ),
                        ),
                      if (r['observaciones'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Observaciones: ${r['observaciones']}'),
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
