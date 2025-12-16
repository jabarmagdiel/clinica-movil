import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api.dart';

/// Pantalla para mostrar las valoraciones de un médico
class PantallaListaValoraciones extends StatefulWidget {
  final int medicoId;
  final String medicoNombre;

  const PantallaListaValoraciones({
    Key? key,
    required this.medicoId,
    required this.medicoNombre,
  }) : super(key: key);

  @override
  State<PantallaListaValoraciones> createState() => _PantallaListaValoracionesState();
}

class _PantallaListaValoracionesState extends State<PantallaListaValoraciones> {
  bool _loading = true;
  List<dynamic> _valoraciones = [];
  Map<String, dynamic>? _estadisticas;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Cargar valoraciones y estadísticas en paralelo
      final resultados = await Future.wait([
        ApiValoraciones.porMedico(widget.medicoId),
        ApiValoraciones.estadisticas(widget.medicoId),
      ]);

      if (!mounted) return;

      final valoracionesResult = resultados[0];
      final estadisticasResult = resultados[1];

      if (valoracionesResult['ok'] == true && estadisticasResult['ok'] == true) {
        setState(() {
          _valoraciones = valoracionesResult['data'] ?? [];
          _estadisticas = estadisticasResult['data'];
          _loading = false;
        });
      } else {
        setState(() {
          _error = valoracionesResult['error'] ?? estadisticasResult['error'] ?? 'Error al cargar datos';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión: $e';
        _loading = false;
      });
    }
  }

  Widget _buildEstadisticas() {
    if (_estadisticas == null) return const SizedBox.shrink();

    final promedio = _estadisticas!['promedio_calificacion'] ?? 0.0;
    final total = _estadisticas!['total_valoraciones'] ?? 0;
    final distribucion = _estadisticas!['distribucion'] ?? {};

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Promedio
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  promedio.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, color: Colors.amber, size: 32),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$total valoracion${total != 1 ? 'es' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 24),

            // Distribución de estrellas
            for (int i = 5; i >= 1; i--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('$i'),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total > 0
                            ? (distribucion[i.toString()] ?? 0) / total
                            : 0,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${distribucion[i.toString()] ?? 0}',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildValoracionCard(Map<String, dynamic> valoracion) {
    final calificacion = valoracion['calificacion'] ?? 0;
    final comentario = valoracion['comentario'] ?? '';
    final pacienteNombre = valoracion['paciente_nombre'] ?? 'Paciente';
    final fechaCreacion = valoracion['fecha_creacion'];

    String fechaTexto = '';
    if (fechaCreacion != null) {
      try {
        final fecha = DateTime.parse(fechaCreacion);
        fechaTexto = DateFormat('dd/MM/yyyy').format(fecha);
      } catch (e) {
        fechaTexto = '';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                CircleAvatar(
                  child: Text(pacienteNombre[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pacienteNombre,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (fechaTexto.isNotEmpty)
                        Text(
                          fechaTexto,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < calificacion ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            
            // Comentario
            if (comentario.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(comentario),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valoraciones'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _cargarDatos,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: _valoraciones.isEmpty
                      ? ListView(
                          children: [
                            _buildEstadisticas(),
                            const SizedBox(height: 32),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.star_border,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Sin valoraciones aún',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sé el primero en valorar a este médico',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          children: [
                            _buildEstadisticas(),
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Opiniones de pacientes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ..._valoraciones.map((v) => _buildValoracionCard(v)),
                            const SizedBox(height: 16),
                          ],
                        ),
                ),
    );
  }
}
