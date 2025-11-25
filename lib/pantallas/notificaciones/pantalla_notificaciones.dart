import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api.dart';
import '../../servicios/servicio_notificaciones.dart';

class PantallaNotificaciones extends StatefulWidget {
  const PantallaNotificaciones({super.key});

  @override
  State<PantallaNotificaciones> createState() => _PantallaNotificacionesState();
}

class _PantallaNotificacionesState extends State<PantallaNotificaciones> {
  bool loading = true;
  List<Map<String, dynamic>> notificaciones = [];
  String? filtroTipo; // 'cita', 'resultado', 'general', null = todas
  String? filtroEstado; // 'leida', 'no_leida', null = todas
  int currentPage = 1;
  bool hasMore = true;
  int notificacionesNoLeidas = 0;

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
    _contarNoLeidas();
  }

  Future<void> _cargarNotificaciones({bool reset = false}) async {
    if (reset) {
      currentPage = 1;
      notificaciones.clear();
    }
    setState(() => loading = true);

    final res = await ApiNotificaciones.listar(
      tipo: filtroTipo,
      leida: filtroEstado == 'leida' ? true : filtroEstado == 'no_leida' ? false : null,
      page: currentPage,
    );

    if (res['ok'] == true) {
      final nuevaLista = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        notificaciones = reset ? nuevaLista : [...notificaciones, ...nuevaLista];
        hasMore = res['next'] != null;
        loading = false;
      });
    } else {
      setState(() => loading = false);
      // Si el endpoint no existe, mostrar datos de ejemplo
      if (res['error']?.toString().contains('404') == true && notificaciones.isEmpty) {
        setState(() {
          notificaciones = _getNotificacionesMock();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Endpoint de notificaciones no disponible. Mostrando datos de ejemplo.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error']?.toString() ?? 'Error al cargar notificaciones')),
          );
        }
      }
    }
  }

  Future<void> _contarNoLeidas() async {
    final res = await ApiNotificaciones.contarNoLeidas();
    if (res['ok'] == true) {
      setState(() {
        notificacionesNoLeidas = res['data']['count'] ?? 0;
      });
    }
  }

  List<Map<String, dynamic>> _getNotificacionesMock() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'tipo': 'cita',
        'titulo': '📅 Cita Confirmada',
        'mensaje': 'Su cita con Dr. Luis García para el 25/11/2024 a las 10:00 ha sido confirmada.',
        'leida': false,
        'fecha_creacion': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'datos_adicionales': {
          'cita_id': '123',
          'medico': 'Dr. Luis García',
          'fecha': '25/11/2024',
          'hora': '10:00'
        }
      },
      {
        'id': 2,
        'tipo': 'resultado',
        'titulo': '🧪 Resultados de Examen Disponibles',
        'mensaje': 'Los resultados de su examen de sangre están disponibles.',
        'leida': false,
        'fecha_creacion': now.subtract(const Duration(hours: 5)).toIso8601String(),
        'datos_adicionales': {
          'examen_id': '456',
          'tipo_examen': 'Análisis de sangre'
        }
      },
      {
        'id': 3,
        'tipo': 'cita',
        'titulo': '📅 Nueva Cita Agendada',
        'mensaje': 'Se ha agendado una cita con Dr. Elena Martínez para el 28/11/2024 a las 15:30.',
        'leida': true,
        'fecha_creacion': now.subtract(const Duration(days: 1)).toIso8601String(),
        'datos_adicionales': {
          'cita_id': '789',
          'medico': 'Dr. Elena Martínez',
          'fecha': '28/11/2024',
          'hora': '15:30'
        }
      },
      {
        'id': 4,
        'tipo': 'general',
        'titulo': '🏥 Recordatorio de Consulta',
        'mensaje': 'Recuerde traer sus exámenes previos a la consulta de mañana.',
        'leida': true,
        'fecha_creacion': now.subtract(const Duration(days: 2)).toIso8601String(),
        'datos_adicionales': {}
      },
    ];
  }

  Future<void> _marcarComoLeida(int notificacionId) async {
    final res = await ApiNotificaciones.marcarComoLeida(notificacionId);
    if (res['ok'] == true) {
      setState(() {
        final index = notificaciones.indexWhere((n) => n['id'] == notificacionId);
        if (index != -1) {
          notificaciones[index]['leida'] = true;
          if (notificacionesNoLeidas > 0) {
            notificacionesNoLeidas--;
          }
        }
      });
    }
  }

  Future<void> _marcarTodasComoLeidas() async {
    final res = await ApiNotificaciones.marcarTodasComoLeidas();
    if (res['ok'] == true) {
      setState(() {
        for (var notificacion in notificaciones) {
          notificacion['leida'] = true;
        }
        notificacionesNoLeidas = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas las notificaciones marcadas como leídas')),
        );
      }
    }
  }

  Future<void> _eliminarNotificacion(int notificacionId) async {
    final res = await ApiNotificaciones.eliminar(notificacionId);
    if (res['ok'] == true) {
      setState(() {
        notificaciones.removeWhere((n) => n['id'] == notificacionId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación eliminada')),
        );
      }
    }
  }

  void _mostrarDetalles(Map<String, dynamic> notificacion) {
    if (!notificacion['leida']) {
      _marcarComoLeida(notificacion['id']);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notificacion['titulo'] ?? 'Notificación'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notificacion['mensaje'] ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Fecha: ${_formatearFecha(notificacion['fecha_creacion'])}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Tipo: ${_getTipoTexto(notificacion['tipo'])}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (notificacion['datos_adicionales'] != null && 
                  (notificacion['datos_adicionales'] as Map).isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Información adicional:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...((notificacion['datos_adicionales'] as Map<String, dynamic>).entries.map((entry) =>
                  Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 12))
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (notificacion['tipo'] == 'cita' && notificacion['datos_adicionales']?['cita_id'] != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                // Navegar a detalles de cita
                _navegarACita(notificacion['datos_adicionales']['cita_id']);
              },
              child: const Text('Ver Cita'),
            ),
        ],
      ),
    );
  }

  void _navegarACita(String citaId) {
    // Implementar navegación a detalles de cita
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navegando a cita ID: $citaId')),
    );
  }

  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null) return '';
    try {
      final fecha = DateTime.parse(fechaStr);
      final now = DateTime.now();
      final difference = now.difference(fecha);
      
      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return 'Hace ${difference.inMinutes} minutos';
        }
        return 'Hace ${difference.inHours} horas';
      } else if (difference.inDays == 1) {
        return 'Ayer';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} días';
      } else {
        return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
      }
    } catch (e) {
      return fechaStr;
    }
  }

  String _getTipoTexto(String? tipo) {
    switch (tipo) {
      case 'cita': return 'Cita médica';
      case 'resultado': return 'Resultado de examen';
      case 'general': return 'General';
      default: return 'Notificación';
    }
  }

  IconData _getTipoIcono(String? tipo) {
    switch (tipo) {
      case 'cita': return Icons.calendar_today;
      case 'resultado': return Icons.science;
      case 'general': return Icons.info;
      default: return Icons.notifications;
    }
  }

  Color _getTipoColor(String? tipo) {
    switch (tipo) {
      case 'cita': return Colors.blue;
      case 'resultado': return Colors.green;
      case 'general': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notificaciones'),
            if (notificacionesNoLeidas > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$notificacionesNoLeidas',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Probar Notificación Emergente',
            onPressed: () async {
              await ServicioNotificaciones.probarNotificacionEmergente();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notificación de prueba enviada')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'marcar_todas_leidas') {
                _marcarTodasComoLeidas();
              } else if (value == 'filtro_tipo') {
                _mostrarFiltroTipo();
              } else if (value == 'filtro_estado') {
                _mostrarFiltroEstado();
              }
            },
            itemBuilder: (context) => [
              if (notificacionesNoLeidas > 0)
                const PopupMenuItem(
                  value: 'marcar_todas_leidas',
                  child: Row(
                    children: [
                      Icon(Icons.done_all),
                      SizedBox(width: 8),
                      Text('Marcar todas como leídas'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'filtro_tipo',
                child: Row(
                  children: [
                    Icon(Icons.filter_list),
                    SizedBox(width: 8),
                    Text('Filtrar por tipo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'filtro_estado',
                child: Row(
                  children: [
                    Icon(Icons.visibility),
                    SizedBox(width: 8),
                    Text('Filtrar por estado'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: loading && notificaciones.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notificaciones.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No hay notificaciones', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _cargarNotificaciones(reset: true),
                  child: ListView.builder(
                    itemCount: notificaciones.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == notificaciones.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                currentPage++;
                                _cargarNotificaciones();
                              },
                              child: const Text('Cargar más'),
                            ),
                          ),
                        );
                      }

                      final notificacion = notificaciones[index];
                      final esNoLeida = !(notificacion['leida'] ?? false);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        elevation: esNoLeida ? 3 : 1,
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getTipoColor(notificacion['tipo']),
                                child: Icon(
                                  _getTipoIcono(notificacion['tipo']),
                                  color: Colors.white,
                                ),
                              ),
                              if (esNoLeida)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            notificacion['titulo'] ?? '',
                            style: TextStyle(
                              fontWeight: esNoLeida ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notificacion['mensaje'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatearFecha(notificacion['fecha_creacion']),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => _mostrarDetalles(notificacion),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              if (esNoLeida)
                                const PopupMenuItem(
                                  value: 'marcar_leida',
                                  child: Row(
                                    children: [
                                      Icon(Icons.done),
                                      SizedBox(width: 8),
                                      Text('Marcar como leída'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'marcar_leida') {
                                _marcarComoLeida(notificacion['id']);
                              } else if (value == 'eliminar') {
                                _eliminarNotificacion(notificacion['id']);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _mostrarFiltroTipo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por tipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('Todas'),
              value: null,
              groupValue: filtroTipo,
              onChanged: (value) {
                setState(() => filtroTipo = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Citas médicas'),
              value: 'cita',
              groupValue: filtroTipo,
              onChanged: (value) {
                setState(() => filtroTipo = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Resultados de exámenes'),
              value: 'resultado',
              groupValue: filtroTipo,
              onChanged: (value) {
                setState(() => filtroTipo = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Generales'),
              value: 'general',
              groupValue: filtroTipo,
              onChanged: (value) {
                setState(() => filtroTipo = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFiltroEstado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('Todas'),
              value: null,
              groupValue: filtroEstado,
              onChanged: (value) {
                setState(() => filtroEstado = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
            RadioListTile<String?>(
              title: const Text('No leídas'),
              value: 'no_leida',
              groupValue: filtroEstado,
              onChanged: (value) {
                setState(() => filtroEstado = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
            RadioListTile<String?>(
              title: const Text('Leídas'),
              value: 'leida',
              groupValue: filtroEstado,
              onChanged: (value) {
                setState(() => filtroEstado = value);
                Navigator.pop(context);
                _cargarNotificaciones(reset: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
