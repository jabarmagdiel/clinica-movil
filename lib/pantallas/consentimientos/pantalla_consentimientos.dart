import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../api.dart';

class PantallaConsentimientos extends StatefulWidget {
  const PantallaConsentimientos({super.key});

  @override
  State<PantallaConsentimientos> createState() => _PantallaConsentimientosState();
}

class _PantallaConsentimientosState extends State<PantallaConsentimientos> {
  bool loading = true;
  String? filtroEstado; // 'pendiente', 'firmado', null = todos
  List<Map<String, dynamic>> consentimientos = [];
  int currentPage = 1;
  bool hasMore = true;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _cargarConsentimientos();
  }

  Future<void> _checkBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _biometricAvailable = canCheck || isDeviceSupported;
      });
    } catch (_) {
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _cargarConsentimientos({bool reset = false}) async {
    if (reset) {
      currentPage = 1;
      consentimientos.clear();
    }
    setState(() => loading = true);
    final res = await ApiConsentimientos.listar(
      estado: filtroEstado,
      page: currentPage,
    );
    if (res['ok'] == true) {
      final nuevaLista = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        consentimientos = reset ? nuevaLista : [...consentimientos, ...nuevaLista];
        hasMore = res['next'] != null;
        loading = false;
      });
    } else {
      setState(() => loading = false);
      final errorMsg = res['error']?.toString() ?? 'Error al cargar';
      
      // Si el error contiene 404, mostrar mensaje más amigable
      if (errorMsg.contains('404') || errorMsg.contains('Page not found')) {
        if (mounted && consentimientos.isEmpty) {
          // Mostrar datos de ejemplo si el endpoint no existe
          setState(() {
            consentimientos = _getConsentimientosMock();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Endpoint de consentimientos no disponible. Mostrando datos de ejemplo.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _getConsentimientosMock() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'tipo': 'Consentimiento Informado',
        'tipo_consentimiento': 'Consentimiento Informado',
        'procedimiento': 'Cirugía de rodilla',
        'nombre_procedimiento': 'Cirugía de rodilla',
        'medico_nombre': 'Javier',
        'medico_apellido': 'Rodríguez',
        'fecha_creacion': now.subtract(const Duration(days: 5)).toIso8601String(),
        'estado': 'pendiente',
        'contenido': 'El paciente consiente en someterse al procedimiento quirúrgico de rodilla bajo anestesia general. Se han explicado los riesgos y beneficios.',
      },
      {
        'id': 2,
        'tipo': 'Consentimiento para Anestesia',
        'tipo_consentimiento': 'Consentimiento para Anestesia',
        'procedimiento': 'Anestesia general',
        'nombre_procedimiento': 'Anestesia general',
        'medico_nombre': 'Luis',
        'medico_apellido': 'García',
        'fecha_creacion': now.subtract(const Duration(days: 3)).toIso8601String(),
        'fecha_firma': now.subtract(const Duration(days: 2)).toIso8601String(),
        'estado': 'firmado',
        'tipo_firma': 'biometrica',
        'contenido': 'Consentimiento para la administración de anestesia general durante el procedimiento quirúrgico.',
      },
      {
        'id': 3,
        'tipo': 'Consentimiento para Procedimiento Diagnóstico',
        'tipo_consentimiento': 'Consentimiento para Procedimiento Diagnóstico',
        'procedimiento': 'Endoscopia',
        'nombre_procedimiento': 'Endoscopia',
        'medico_nombre': 'Elena',
        'medico_apellido': 'Martínez',
        'fecha_creacion': now.subtract(const Duration(days: 10)).toIso8601String(),
        'estado': 'pendiente',
        'contenido': 'Consentimiento para realizar endoscopia digestiva alta con fines diagnósticos.',
      },
    ];
  }

  Future<void> _firmarConBiometrica(int consentimientoId) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentícate para firmar el consentimiento',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        await _enviarFirma(consentimientoId, 'biometrica');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticación cancelada')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _firmarConPin(int consentimientoId) async {
    final pinCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firmar con PIN'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ingresa tu PIN',
            hintText: 'PIN de 4-6 dígitos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (pinCtrl.text.length >= 4) {
                Navigator.pop(context);
                _enviarFirma(consentimientoId, 'pin', pin: pinCtrl.text);
              }
            },
            child: const Text('Firmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarFirma(int consentimientoId, String tipoFirma, {String? pin}) async {
    setState(() => loading = true);
    final res = await ApiConsentimientos.firmar(
      consentimientoId: consentimientoId,
      tipoFirma: tipoFirma,
      pin: pin,
    );
    setState(() => loading = false);

    if (res['ok'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consentimiento firmado exitosamente')),
        );
        await _cargarConsentimientos(reset: true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Error al firmar')),
        );
      }
    }
  }

  Future<void> _verDetalles(int consentimientoId) async {
    final res = await ApiConsentimientos.obtener(consentimientoId);
    if (res['ok'] == true && mounted) {
      final data = res['data'] as Map<String, dynamic>;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(data['tipo'] ?? 'Consentimiento'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data['contenido'] != null || data['texto'] != null) 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      data['contenido'] ?? data['texto'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                const Divider(),
                const SizedBox(height: 8),
                Text('Paciente: ${data['paciente_nombre'] ?? ''} ${data['paciente_apellido'] ?? ''}'),
                Text('Médico: ${data['medico_nombre'] ?? ''} ${data['medico_apellido'] ?? ''}'),
                if (data['procedimiento'] != null || data['nombre_procedimiento'] != null)
                  Text('Procedimiento: ${data['procedimiento'] ?? data['nombre_procedimiento'] ?? ''}'),
                Text('Fecha creación: ${data['fecha_creacion']?.toString().split('T').first ?? data['fecha']?.toString().split('T').first ?? ''}'),
                Text(
                  'Estado: ${data['estado'] ?? 'Pendiente'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (data['estado'] ?? 'Pendiente').toString().toLowerCase() == 'firmado' 
                        ? Colors.green 
                        : Colors.orange,
                  ),
                ),
                if (data['fecha_firma'] != null || data['fecha_aceptacion'] != null)
                  Text('Firmado el: ${data['fecha_firma']?.toString().split('T').first ?? data['fecha_aceptacion']?.toString().split('T').first ?? ''}'),
                if (data['tipo_firma'] != null)
                  Text('Tipo de firma: ${data['tipo_firma']}'),
                if (data['version'] != null)
                  Text('Versión: ${data['version']}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consentimientos'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => filtroEstado = value == 'todos' ? null : value);
              _cargarConsentimientos(reset: true);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'todos', child: Text('Todos')),
              const PopupMenuItem(value: 'pendiente', child: Text('Pendientes')),
              const PopupMenuItem(value: 'firmado', child: Text('Firmados')),
            ],
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: loading && consentimientos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : consentimientos.isEmpty
              ? const Center(child: Text('No hay consentimientos'))
              : RefreshIndicator(
                  onRefresh: () => _cargarConsentimientos(reset: true),
                  child: ListView.builder(
                    itemCount: consentimientos.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == consentimientos.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                currentPage++;
                                _cargarConsentimientos();
                              },
                              child: const Text('Cargar más'),
                            ),
                          ),
                        );
                      }
                      final c = consentimientos[index];
                      final estado = c['estado'] ?? 'pendiente';
                      final isFirmado = estado == 'firmado' || estado == 'Firmado';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            isFirmado ? Icons.check_circle : Icons.pending,
                            color: isFirmado ? Colors.green : Colors.orange,
                          ),
                          title: Text(c['tipo'] ?? c['tipo_consentimiento'] ?? 'Consentimiento'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c['procedimiento'] != null || c['nombre_procedimiento'] != null)
                                Text('Procedimiento: ${c['procedimiento'] ?? c['nombre_procedimiento'] ?? 'N/A'}'),
                              Text('Médico: ${c['medico_nombre'] ?? ''} ${c['medico_apellido'] ?? ''}'),
                              Text('Fecha creación: ${c['fecha_creacion']?.toString().split('T').first ?? c['fecha']?.toString().split('T').first ?? ''}'),
                              if (isFirmado && (c['fecha_firma'] != null || c['fecha_aceptacion'] != null))
                                Text('Fecha firma: ${c['fecha_firma']?.toString().split('T').first ?? c['fecha_aceptacion']?.toString().split('T').first ?? ''}'),
                              Text(
                                'Estado: ${isFirmado ? 'Firmado' : 'Pendiente'}',
                                style: TextStyle(
                                  color: isFirmado ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: isFirmado
                              ? IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _verDetalles(c['id'] as int),
                                  tooltip: 'Ver detalles',
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility),
                                      onPressed: () => _verDetalles(c['id'] as int),
                                      tooltip: 'Ver detalles',
                                    ),
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        if (_biometricAvailable)
                                          const PopupMenuItem(
                                            value: 'biometrica',
                                            child: Row(
                                              children: [
                                                Icon(Icons.fingerprint),
                                                SizedBox(width: 8),
                                                Text('Firmar con huella'),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'pin',
                                          child: Row(
                                            children: [
                                              Icon(Icons.lock),
                                              SizedBox(width: 8),
                                              Text('Firmar con PIN'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'biometrica') {
                                          _firmarConBiometrica(c['id'] as int);
                                        } else if (value == 'pin') {
                                          _firmarConPin(c['id'] as int);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
