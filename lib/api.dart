// lib/api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// URLs base
const String kBaseUrlCloud =
    'https://abc-gestion-documental-backend.duckdns.org'; // NUBE
const String kBaseUrlLocal = 'http://10.0.2.2:8000'; // LOCAL (emulador)

// ==> Usa la nube por ahora:
const String kBaseUrl = kBaseUrlCloud;

final storage = FlutterSecureStorage();

class ApiAuth {
  // Endpoints (ajústalos si tu backend usa rutas diferentes)
  static Uri loginUrl() => Uri.parse('$kBaseUrl/api/token/');
  static Uri registerPacienteUrl() =>
      Uri.parse('$kBaseUrl/api/registro/paciente/');
  static Uri meUrl() => Uri.parse('$kBaseUrl/api/me/');

  /// HU07: Login (acepta email o username).
  /// Guarda tokens y el objeto "user" que viene en la respuesta.
  static Future<Map<String, dynamic>> login({
    required String email, // puede ser email o username
    required String password,
  }) async {
    Future<http.Response> _post(Map<String, dynamic> body) {
      return http
          .post(
        loginUrl(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 12));
    }

    try {
      // 1) intenta con email
      var resp = await _post({"email": email, "password": password});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await storage.write(key: 'access', value: data['access']);
        await storage.write(key: 'refresh', value: data['refresh']);
        if (data['user'] != null) {
          await storage.write(key: 'me', value: jsonEncode(data['user']));
        }
        return {'ok': true, 'user': data['user']};
      }

      // 2) intenta con username
      resp = await _post({"username": email, "password": password});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await storage.write(key: 'access', value: data['access']);
        await storage.write(key: 'refresh', value: data['refresh']);
        if (data['user'] != null) {
          await storage.write(key: 'me', value: jsonEncode(data['user']));
        }
        return {'ok': true, 'user': data['user']};
      }

      return {
        'ok': false,
        'error': 'Login falló: ${resp.statusCode} ${resp.body}'
      };
    } catch (e) {
      return {'ok': false, 'error': 'Error de red: $e'};
    }
  }

  /// HU06: Registro de paciente
  static Future<Map<String, dynamic>> registerPaciente({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    final payload = {
      "email": email,
      "password": password,
      "nombre": nombre,
      "apellido": apellido,
      if (telefono != null && telefono.isNotEmpty) "telefono": telefono,
    };

    final resp = await http.post(
      registerPacienteUrl(),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 201) return {'ok': true};
    return {
      'ok': false,
      'error': 'Registro falló (${resp.statusCode}): ${resp.body}'
    };
  }

  /// Perfil (opcional, si existe /api/me/)
  static Future<Map<String, dynamic>> me() async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};
    final resp = await http.get(
      meUrl(),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      return {'ok': true, 'data': jsonDecode(resp.body)};
    }
    return {
      'ok': false,
      'error': 'No se pudo obtener perfil (${resp.statusCode})'
    };
  }

  /// Lee el "user" guardado del login (respaldo cuando /api/me/ no está).
  static Future<Map<String, dynamic>?> getStoredUser() async {
    final raw = await storage.read(key: 'me');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// HU07: Logout (lado cliente)
  static Future<void> logout() async {
    await storage.deleteAll(); // borra tokens y 'me'
  }
}

class ApiCitas {
  static Uri citasUrl() => Uri.parse('$kBaseUrl/api/agenda-citas/');
  static Uri horasDisponiblesUrl(int medicoEspecialidadId, String fecha) =>
      Uri.parse('$kBaseUrl/api/agenda-citas/horas-disponibles/?medico_especialidad=$medicoEspecialidadId&fecha=$fecha');

  // 👇 NUEVO: select de médico–especialidad (según tu screenshot)
  static Uri medicoEspecialidadesUrl() =>
      Uri.parse('$kBaseUrl/api/select/medico-especialidades/');

  /// Select de médico–especialidad
  static Future<Map<String, dynamic>> medicoEspecialidades() async {
    final token = await storage.read(key: 'access');
    final resp = await http.get(
      medicoEspecialidadesUrl(),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return {'ok': true, 'data': list};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}) al cargar médicos'};
  }

  /// Listar citas (paginado o lista simple)
  static Future<Map<String, dynamic>> listar() async {
    final token = await storage.read(key: 'access');
    final resp = await http.get(
      citasUrl(),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {'ok': true, 'data': data is Map ? (data['results'] ?? []) : data};
    }
    return {'ok': false, 'error': 'Error al listar citas (${resp.statusCode})'};
  }

  /// Horas disponibles
  static Future<Map<String, dynamic>> horasDisponibles({
    required int medicoEspecialidadId,
    required String fecha,
  }) async {
    final token = await storage.read(key: 'access');
    final resp = await http.get(
      horasDisponiblesUrl(medicoEspecialidadId, fecha),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {'ok': true, 'data': (data['horas_disponibles'] as List).cast<String>()};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}) al obtener horas'};
  }

  /// Crear cita
  static Future<Map<String, dynamic>> crear({
    required int pacienteId,
    required int medicoEspecialidadId,
    required String fechaCita,
    required String horaCita,
  }) async {
    final token = await storage.read(key: 'access');
    final payload = {
      "paciente": pacienteId,
      "medico_especialidad": medicoEspecialidadId,
      "fecha_cita": fechaCita,
      "hora_cita": horaCita,
    };

    final resp = await http.post(
      citasUrl(),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 201) {
      return {'ok': true, 'data': jsonDecode(resp.body)};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Actualizar cita
  static Future<Map<String, dynamic>> actualizar({
    required int citaId,
    String? fechaCita,
    String? horaCita,
  }) async {
    final token = await storage.read(key: 'access');
    final payload = {
      if (fechaCita != null) "fecha_cita": fechaCita,
      if (horaCita != null) "hora_cita": horaCita,
    };

    final resp = await http.patch(
      Uri.parse('$kBaseUrl/api/agenda-citas/$citaId/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 200) {
      return {'ok': true, 'data': jsonDecode(resp.body)};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Obtiene el usuario (paciente) guardado del login
  static Future<Map<String, dynamic>?> meLocal() => ApiAuth.getStoredUser();
}

// ================== MÉDICOS & ESPECIALIDADES ==================
class ApiMedicos {
  // Ya usaste este select antes (según tus capturas)
  static Uri medicoEspecialidadesUrl() =>
      Uri.parse('$kBaseUrl/api/select/medico-especialidades/');

  /// Devuelve una lista con combinaciones médico–especialidad.
  /// Ejemplo de item:
  /// { "id": 4, "medico": 5, "medico_nombre_completo": "Dr. Elena Martínez",
  ///   "especialidad": 7, "especialidad_nombre": "Ginecología", "especialidad_codigo": "GINE" }
  static Future<Map<String, dynamic>> medicoEspecialidades() async {
    final token = await storage.read(key: 'access');
    final resp = await http.get(
      medicoEspecialidadesUrl(),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return {'ok': true, 'data': list};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}) al cargar médicos'};
  }
}

// ========= PERFIL PERSONAL =========
class ApiPerfil {
  static Uri _usuarioById(int id) => Uri.parse('$kBaseUrl/api/usuarios/$id/');
  static Uri _pacienteById(int id) => Uri.parse('$kBaseUrl/api/pacientes/$id/');

  /// Lee el usuario guardado del login (clave 'me') y devuelve su id
  static Future<int?> _getMyId() async {
    final raw = await storage.read(key: 'me');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Intenta GET en /usuarios/{id}/; si 404, intenta /pacientes/{id}/
  static Future<Map<String, dynamic>> obtener() async {
    final token = await storage.read(key: 'access');
    final myId = await _getMyId();
    if (token == null || myId == null) {
      return {'ok': false, 'error': 'No autenticado o sin ID local'};
    }

    Future<http.Response> _get(Uri url) => http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    // 1) usuarios/{id}/
    var resp = await _get(_usuarioById(myId));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {'ok': true, 'data': data, 'endpoint': 'usuarios'};
    }
    if (resp.statusCode != 404) {
      return {'ok': false, 'error': 'GET usuarios/$myId -> ${resp.statusCode}'};
    }

    // 2) pacientes/{id}/
    resp = await _get(_pacienteById(myId));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {'ok': true, 'data': data, 'endpoint': 'pacientes'};
    }
    return {'ok': false, 'error': 'GET pacientes/$myId -> ${resp.statusCode}'};
  }

  /// PATCH en /usuarios/{id}/; si 404, PATCH en /pacientes/{id}/
  static Future<Map<String, dynamic>> actualizar({
    String? nombre,
    String? apellido,
    String? telefono,
    String? email,
    String? password,
  }) async {
    final token = await storage.read(key: 'access');
    final myId = await _getMyId();
    if (token == null || myId == null) {
      return {'ok': false, 'error': 'No autenticado o sin ID local'};
    }

    final payload = <String, dynamic>{
      if (nombre != null) 'nombre': nombre,
      if (apellido != null) 'apellido': apellido,
      if (telefono != null) 'telefono': telefono,
      if (email != null) 'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
    };

    Future<http.Response> _patch(Uri url) => http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    // 1) usuarios/{id}/
    var resp = await _patch(_usuarioById(myId));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      await storage.write(key: 'me', value: jsonEncode(data)); // refresca cache
      return {'ok': true, 'data': data, 'endpoint': 'usuarios'};
    }
    if (resp.statusCode != 404) {
      return {'ok': false, 'error': 'PATCH usuarios/$myId -> ${resp.statusCode}: ${resp.body}'};
    }

    // 2) pacientes/{id}/
    resp = await _patch(_pacienteById(myId));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      await storage.write(key: 'me', value: jsonEncode(data));
      return {'ok': true, 'data': data, 'endpoint': 'pacientes'};
    }
    return {'ok': false, 'error': 'PATCH pacientes/$myId -> ${resp.statusCode}: ${resp.body}'};
  }
}

// ========= ESPECIALIDAD -> BUSCAR MÉDICO =========
class ApiMedicosSimple {
  static Uri _medicos() => Uri.parse('$kBaseUrl/api/medicos/');
  static Uri _especialidades() => Uri.parse('$kBaseUrl/api/especialidades/');

  /// Trae todas las especialidades
  static Future<Map<String, dynamic>> especialidades() async {
    final token = await storage.read(key: 'access');
    final resp = await http.get(_especialidades(), headers: {
      'Authorization': 'Bearer $token',
    });
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body);
      return {'ok': true, 'data': list is Map ? (list['results'] ?? []) : list};
    }
    return {'ok': false, 'error': 'GET especialidades -> ${resp.statusCode}'};
  }

  /// Trae todos los médicos
  static Future<Map<String, dynamic>> medicos({int? especialidadId}) async {
    final token = await storage.read(key: 'access');
    final base = _medicos();
    final uri = (especialidadId == null)
        ? base
        : base.replace(queryParameters: {'especialidad': '$especialidadId'});
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body);
      return {'ok': true, 'data': list is Map ? (list['results'] ?? []) : list};
    }
    return {'ok': false, 'error': 'GET medicos -> ${resp.statusCode}'};
  }
}

// ========= HISTORIA CLÍNICA =========
class ApiHistoriaClinica {
  static Uri _historiaUrl() => Uri.parse('$kBaseUrl/api/historia-clinica/');
  static Uri _consultasUrl() => Uri.parse('$kBaseUrl/api/consultas/');
  static Uri _examenesUrl() => Uri.parse('$kBaseUrl/api/examenes/');
  static Uri _recetasUrl() => Uri.parse('$kBaseUrl/api/recetas/');
  static Uri _downloadPdfUrl() => Uri.parse('$kBaseUrl/api/historia-clinica/descargar-pdf/');

  /// Obtiene el ID del paciente autenticado
  static Future<int?> _getPacienteId() async {
    final raw = await storage.read(key: 'me');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Lista consultas del paciente con filtros y paginación
  static Future<Map<String, dynamic>> listarConsultas({
    String? fechaDesde,
    String? fechaHasta,
    int? medicoId,
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;
    if (medicoId != null) queryParams['medico'] = medicoId.toString();
    if (page != null) queryParams['page'] = page.toString();

    final uri = _consultasUrl().replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {
        'ok': true,
        'data': data is Map ? (data['results'] ?? []) : data,
        'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        'next': data is Map ? data['next'] : null,
        'previous': data is Map ? data['previous'] : null,
      };
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Lista exámenes del paciente con filtros y paginación
  static Future<Map<String, dynamic>> listarExamenes({
    String? fechaDesde,
    String? fechaHasta,
    int? medicoId,
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;
    if (medicoId != null) queryParams['medico'] = medicoId.toString();
    if (page != null) queryParams['page'] = page.toString();

    final uri = _examenesUrl().replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {
        'ok': true,
        'data': data is Map ? (data['results'] ?? []) : data,
        'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        'next': data is Map ? data['next'] : null,
        'previous': data is Map ? data['previous'] : null,
      };
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Lista recetas del paciente con filtros y paginación
  static Future<Map<String, dynamic>> listarRecetas({
    String? fechaDesde,
    String? fechaHasta,
    int? medicoId,
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;
    if (medicoId != null) queryParams['medico'] = medicoId.toString();
    if (page != null) queryParams['page'] = page.toString();

    final uri = _recetasUrl().replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {
        'ok': true,
        'data': data is Map ? (data['results'] ?? []) : data,
        'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        'next': data is Map ? data['next'] : null,
        'previous': data is Map ? data['previous'] : null,
      };
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Obtiene toda la historia clínica completa (consultas, exámenes, recetas)
  static Future<Map<String, dynamic>> obtenerHistoriaCompleta({
    String? fechaDesde,
    String? fechaHasta,
    int? medicoId,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;
    if (medicoId != null) queryParams['medico'] = medicoId.toString();

    final uri = _historiaUrl().replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {'ok': true, 'data': data};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Descarga la historia clínica en PDF
  static Future<Map<String, dynamic>> descargarPdf({
    String? fechaDesde,
    String? fechaHasta,
    int? medicoId,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;
    if (medicoId != null) queryParams['medico'] = medicoId.toString();

    final uri = _downloadPdfUrl().replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (resp.statusCode == 200) {
      return {'ok': true, 'data': resp.bodyBytes, 'contentType': resp.headers['content-type']};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }
}

// ========= CONSENTIMIENTOS =========
class ApiConsentimientos {
  static Uri _consentimientosUrl() => Uri.parse('$kBaseUrl/api/consentimientos/');
  static Uri _consentimientoById(int id) => Uri.parse('$kBaseUrl/api/consentimientos/$id/');
  static Uri _firmarUrl(int id) => Uri.parse('$kBaseUrl/api/consentimientos/$id/firmar/');

  /// Obtiene el ID del paciente autenticado
  static Future<int?> _getPacienteId() async {
    final raw = await storage.read(key: 'me');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Lista consentimientos del paciente (pendientes y firmados)
  static Future<Map<String, dynamic>> listar({
    String? estado, // 'pendiente', 'firmado'
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (estado != null) queryParams['estado'] = estado;
    if (page != null) queryParams['page'] = page.toString();

    final uri = _consentimientosUrl().replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return {
        'ok': true,
        'data': data is Map ? (data['results'] ?? []) : data,
        'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        'next': data is Map ? data['next'] : null,
        'previous': data is Map ? data['previous'] : null,
      };
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Obtiene detalles de un consentimiento específico
  static Future<Map<String, dynamic>> obtener(int consentimientoId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final resp = await http.get(
      _consentimientoById(consentimientoId),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 200) {
      return {'ok': true, 'data': jsonDecode(resp.body)};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }

  /// Firma un consentimiento usando PIN o huella biométrica
  static Future<Map<String, dynamic>> firmar({
    required int consentimientoId,
    required String tipoFirma, // 'pin' o 'biometrica'
    String? pin,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      'tipo_firma': tipoFirma,
      if (pin != null) 'pin': pin,
    };

    final resp = await http.post(
      _firmarUrl(consentimientoId),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return {'ok': true, 'data': jsonDecode(resp.body)};
    }
    return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
  }
}

/// =================== NOTIFICACIONES ===================
class ApiNotificaciones {
  // URLs
  static Uri _notificacionesUrl() => Uri.parse('$kBaseUrl/api/notificaciones/');
  static Uri _notificacionById(int id) => Uri.parse('$kBaseUrl/api/notificaciones/$id/');
  static Uri _marcarLeidaUrl(int id) => Uri.parse('$kBaseUrl/api/notificaciones/$id/marcar_leida/');
  static Uri _marcarTodasLeidasUrl() => Uri.parse('$kBaseUrl/api/notificaciones/marcar_todas_leidas/');
  static Uri _contarNoLeidasUrl() => Uri.parse('$kBaseUrl/api/notificaciones/contar_no_leidas/');
  static Uri _registrarDispositivoUrl() => Uri.parse('$kBaseUrl/api/dispositivos/');

  /// Lista notificaciones del usuario
  static Future<Map<String, dynamic>> listar({
    String? tipo, // 'cita', 'resultado', 'general'
    bool? leida,
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (tipo != null) queryParams['tipo'] = tipo;
    if (leida != null) queryParams['leida'] = leida.toString();
    if (page != null) queryParams['page'] = page.toString();

    final uri = _notificacionesUrl().replace(queryParameters: queryParams);
    
    try {
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'ok': true,
          'data': data is Map ? (data['results'] ?? []) : data,
          'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
          'next': data is Map ? data['next'] : null,
          'previous': data is Map ? data['previous'] : null,
        };
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Marca una notificación como leída
  static Future<Map<String, dynamic>> marcarComoLeida(int notificacionId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.post(
        _marcarLeidaUrl(notificacionId),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Marca todas las notificaciones como leídas
  static Future<Map<String, dynamic>> marcarTodasComoLeidas() async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.post(
        _marcarTodasLeidasUrl(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Cuenta las notificaciones no leídas
  static Future<Map<String, dynamic>> contarNoLeidas() async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _contarNoLeidasUrl(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Elimina una notificación
  static Future<Map<String, dynamic>> eliminar(int notificacionId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.delete(
        _notificacionById(notificacionId),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 204 || resp.statusCode == 200) {
        return {'ok': true};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Registra un dispositivo para notificaciones FCM
  static Future<Map<String, dynamic>> registrarDispositivo(String tokenFCM) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    // Obtener información del usuario actual
    final userInfo = await ApiPerfil.obtener();
    if (userInfo['ok'] != true) {
      print('❌ Error obteniendo perfil: ${userInfo['error']}');
      return {'ok': false, 'error': 'No se pudo obtener información del usuario'};
    }

    final userId = userInfo['data']['id'];
    print('👤 Registrando dispositivo para usuario ID: $userId');

    final payload = {
      'usuario': userId, // ID del usuario requerido por el backend
      'token_fcm': tokenFCM,
      'plataforma': 'android',
    };

    print('📤 Registrando dispositivo con payload: $payload');

    try {
      final resp = await http.post(
        _registrarDispositivoUrl(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        print('✅ Dispositivo registrado exitosamente');
        return {'ok': true, 'data': jsonDecode(resp.body)};
      } else if (resp.statusCode == 400) {
        final errorBody = resp.body;
        if (errorBody.contains('Ya existe Dispositivo con este token fcm')) {
          print('ℹ️ Token ya registrado - esto es normal');
          return {'ok': true, 'message': 'Token ya registrado'};
        }
        print('❌ Error 400: $errorBody');
        return {'ok': false, 'error': 'Error (${resp.statusCode}): $errorBody'};
      } else {
        print('❌ Error ${resp.statusCode}: ${resp.body}');
        return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
      }
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }
}

// =================== VALORACIONES ===================
class ApiValoraciones {
  static Uri _valoracionesUrl() => Uri.parse('$kBaseUrl/api/valoraciones/');
  static Uri _valoracionById(int id) => Uri.parse('$kBaseUrl/api/valoraciones/$id/');
  static Uri _porMedicoUrl(int medicoId) => Uri.parse('$kBaseUrl/api/valoraciones/medico/$medicoId/');
  static Uri _misValoracionesUrl() => Uri.parse('$kBaseUrl/api/valoraciones/mis-valoraciones/');
  static Uri _estadisticasUrl(int medicoId) => Uri.parse('$kBaseUrl/api/valoraciones/estadisticas-medico/$medicoId/');

  /// Lista todas las valoraciones (admin) o del paciente actual
  static Future<Map<String, dynamic>> listar({int? page}) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (page != null) queryParams['page'] = page.toString();

    final uri = _valoracionesUrl().replace(queryParameters: queryParams);
    
    try {
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'ok': true,
          'data': data is Map ? (data['results'] ?? []) : data,
          'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        };
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene valoraciones de un médico específico
  static Future<Map<String, dynamic>> porMedico(int medicoId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _porMedicoUrl(medicoId),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {'ok': true, 'data': data is Map ? (data['results'] ?? []) : data};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene las valoraciones del paciente actual
  static Future<Map<String, dynamic>> misValoraciones() async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _misValoracionesUrl(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene estadísticas de valoraciones de un médico
  static Future<Map<String, dynamic>> estadisticas(int medicoId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _estadisticasUrl(medicoId),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Crea una nueva valoración
  static Future<Map<String, dynamic>> crear({
    required int pacienteId,
    required int medicoId,
    required int calificacion,
    String? comentario,
    int? consultaId,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      'paciente': pacienteId,
      'medico': medicoId,
      'calificacion': calificacion,
      if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
      if (consultaId != null) 'consulta': consultaId,
    };

    try {
      final resp = await http.post(
        _valoracionesUrl(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 201) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Actualiza una valoración existente
  static Future<Map<String, dynamic>> actualizar({
    required int valoracionId,
    int? calificacion,
    String? comentario,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      if (calificacion != null) 'calificacion': calificacion,
      if (comentario != null) 'comentario': comentario,
    };

    try {
      final resp = await http.patch(
        _valoracionById(valoracionId),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Elimina una valoración
  static Future<Map<String, dynamic>> eliminar(int valoracionId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.delete(
        _valoracionById(valoracionId),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 204) {
        return {'ok': true};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }
}

// =================== INVENTARIO ===================
class ApiInventario {
  // URLs Categorías
  static Uri _categoriasUrl() => Uri.parse('$kBaseUrl/api/inventario/categorias/');
  static Uri _categoriaById(int id) => Uri.parse('$kBaseUrl/api/inventario/categorias/$id/');
  
  // URLs Items
  static Uri _itemsUrl() => Uri.parse('$kBaseUrl/api/inventario/items/');
  static Uri _itemById(int id) => Uri.parse('$kBaseUrl/api/inventario/items/$id/');
  static Uri _alertasUrl() => Uri.parse('$kBaseUrl/api/inventario/items/alertas/');
  static Uri _movimientosItemUrl(int itemId) => Uri.parse('$kBaseUrl/api/inventario/items/$itemId/movimientos/');
  
  // URLs Movimientos
  static Uri _movimientosUrl() => Uri.parse('$kBaseUrl/api/inventario/movimientos/');
  static Uri _movimientoById(int id) => Uri.parse('$kBaseUrl/api/inventario/movimientos/$id/');
  static Uri _resumenMovimientosUrl() => Uri.parse('$kBaseUrl/api/inventario/movimientos/resumen/');

  // ========== CATEGORÍAS ==========

  /// Lista categorías de inventario
  static Future<Map<String, dynamic>> listarCategorias() async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _categoriasUrl(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {'ok': true, 'data': data is Map ? (data['results'] ?? []) : data};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Crea una nueva categoría
  static Future<Map<String, dynamic>> crearCategoria({
    required String nombre,
    String? descripcion,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      'nombre': nombre,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
    };

    try {
      final resp = await http.post(
        _categoriasUrl(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 201) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  // ========== ITEMS ==========

  /// Lista items de inventario
  static Future<Map<String, dynamic>> listarItems({
    String? tipo,
    int? categoriaId,
    String? estadoStock,
    String? search,
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (tipo != null) queryParams['tipo'] = tipo;
    if (categoriaId != null) queryParams['categoria'] = categoriaId.toString();
    if (estadoStock != null) queryParams['estado_stock'] = estadoStock;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (page != null) queryParams['page'] = page.toString();

    final uri = _itemsUrl().replace(queryParameters: queryParams);

    try {
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'ok': true,
          'data': data is Map ? (data['results'] ?? []) : data,
          'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        };
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene un item específico
  static Future<Map<String, dynamic>> obtenerItem(int itemId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _itemById(itemId),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Crea un nuevo item
  static Future<Map<String, dynamic>> crearItem({
    required String codigo,
    required String nombre,
    required String tipo,
    required String unidadMedida,
    String? descripcion,
    int? categoriaId,
    int? cantidadActual,
    int? cantidadMinima,
    double? precioUnitario,
    String? fechaVencimiento,
    String? lote,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      'codigo': codigo,
      'nombre': nombre,
      'tipo': tipo,
      'unidad_medida': unidadMedida,
      if (descripcion != null) 'descripcion': descripcion,
      if (categoriaId != null) 'categoria': categoriaId,
      if (cantidadActual != null) 'cantidad_actual': cantidadActual,
      if (cantidadMinima != null) 'cantidad_minima': cantidadMinima,
      if (precioUnitario != null) 'precio_unitario': precioUnitario,
      if (fechaVencimiento != null) 'fecha_vencimiento': fechaVencimiento,
      if (lote != null) 'lote': lote,
    };

    try {
      final resp = await http.post(
        _itemsUrl(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 201) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Actualiza un item existente
  static Future<Map<String, dynamic>> actualizarItem({
    required int itemId,
    String? nombre,
    String? descripcion,
    int? categoriaId,
    int? cantidadMinima,
    double? precioUnitario,
    String? fechaVencimiento,
    String? lote,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (categoriaId != null) 'categoria': categoriaId,
      if (cantidadMinima != null) 'cantidad_minima': cantidadMinima,
      if (precioUnitario != null) 'precio_unitario': precioUnitario,
      if (fechaVencimiento != null) 'fecha_vencimiento': fechaVencimiento,
      if (lote != null) 'lote': lote,
    };

    try {
      final resp = await http.patch(
        _itemById(itemId),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene items con stock bajo (alertas)
  static Future<Map<String, dynamic>> obtenerAlertas() async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _alertasUrl(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  // ========== MOVIMIENTOS ==========

  /// Lista movimientos de inventario
  static Future<Map<String, dynamic>> listarMovimientos({
    int? itemId,
    String? tipoMovimiento,
    int? page,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (itemId != null) queryParams['item'] = itemId.toString();
    if (tipoMovimiento != null) queryParams['tipo_movimiento'] = tipoMovimiento;
    if (page != null) queryParams['page'] = page.toString();

    final uri = _movimientosUrl().replace(queryParameters: queryParams);

    try {
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'ok': true,
          'data': data is Map ? (data['results'] ?? []) : data,
          'count': data is Map ? (data['count'] ?? 0) : (data as List).length,
        };
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene movimientos de un item específico
  static Future<Map<String, dynamic>> movimientosItem(int itemId) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    try {
      final resp = await http.get(
        _movimientosItemUrl(itemId),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {'ok': true, 'data': data is Map ? (data['results'] ?? []) : data};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Registra un movimiento de inventario (entrada/salida/ajuste)
  static Future<Map<String, dynamic>> registrarMovimiento({
    required int itemId,
    required String tipoMovimiento,
    required int cantidad,
    required String motivo,
    required int usuarioId,
    String? referencia,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final payload = {
      'item': itemId,
      'tipo_movimiento': tipoMovimiento,
      'cantidad': cantidad,
      'motivo': motivo,
      'usuario': usuarioId,
      if (referencia != null && referencia.isNotEmpty) 'referencia': referencia,
    };

    try {
      final resp = await http.post(
        _movimientosUrl(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 201) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Obtiene resumen de movimientos
  static Future<Map<String, dynamic>> resumenMovimientos({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final token = await storage.read(key: 'access');
    if (token == null) return {'ok': false, 'error': 'No autenticado'};

    final queryParams = <String, String>{};
    if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;

    final uri = _resumenMovimientosUrl().replace(queryParameters: queryParams);

    try {
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(resp.body)};
      }
      return {'ok': false, 'error': 'Error (${resp.statusCode}): ${resp.body}'};
    } catch (e) {
      return {'ok': false, 'error': 'Error de conexión: $e'};
    }
  }
}

