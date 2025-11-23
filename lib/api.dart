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

