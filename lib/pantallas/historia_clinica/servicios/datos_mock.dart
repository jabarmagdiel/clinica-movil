class DatosMock {
  static List<Map<String, dynamic>> getConsultasMock() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'fecha': now.subtract(const Duration(days: 30)).toIso8601String(),
        'medico_nombre': 'Luis',
        'medico_apellido': 'García',
        'especialidad_nombre': 'Cardiología',
        'motivo': 'Control de presión arterial',
        'diagnostico': 'Hipertensión controlada',
        'observaciones': 'Paciente con buena respuesta al tratamiento. Continuar con medicación.',
        'sintomas': 'Dolor de cabeza ocasional',
      },
      {
        'id': 2,
        'fecha': now.subtract(const Duration(days: 15)).toIso8601String(),
        'medico_nombre': 'Elena',
        'medico_apellido': 'Martínez',
        'especialidad_nombre': 'Ginecología',
        'motivo': 'Consulta de rutina',
        'diagnostico': 'Estado de salud normal',
        'observaciones': 'Revisión anual sin complicaciones',
        'sintomas': 'Ninguno',
      },
      {
        'id': 3,
        'fecha': now.subtract(const Duration(days: 7)).toIso8601String(),
        'medico_nombre': 'Javier',
        'medico_apellido': 'Rodríguez',
        'especialidad_nombre': 'Traumatología',
        'motivo': 'Dolor en rodilla izquierda',
        'diagnostico': 'Tendinitis',
        'observaciones': 'Recomendado reposo y fisioterapia',
        'sintomas': 'Dolor al caminar y subir escaleras',
      },
    ];
  }

  static List<Map<String, dynamic>> getExamenesMock() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'tipo_examen': 'Análisis de sangre completo',
        'fecha': now.subtract(const Duration(days: 25)).toIso8601String(),
        'medico_nombre': 'Luis',
        'medico_apellido': 'García',
        'resultado': 'Hemograma normal, colesterol: 180 mg/dL (normal)',
        'laboratorio': 'Laboratorio Central',
        'estado': 'Completado',
        'observaciones': 'Valores dentro de parámetros normales',
      },
      {
        'id': 2,
        'tipo_examen': 'Radiografía de tórax',
        'fecha': now.subtract(const Duration(days: 20)).toIso8601String(),
        'medico_nombre': 'Elena',
        'medico_apellido': 'Martínez',
        'resultado': 'Sin alteraciones pulmonares',
        'laboratorio': 'Centro de Imágenes',
        'estado': 'Completado',
        'observaciones': 'Pulmones limpios, sin signos patológicos',
      },
      {
        'id': 3,
        'tipo_examen': 'Ecografía abdominal',
        'fecha': now.subtract(const Duration(days: 10)).toIso8601String(),
        'medico_nombre': 'Javier',
        'medico_apellido': 'Rodríguez',
        'resultado': 'Órganos abdominales normales',
        'laboratorio': 'Centro de Diagnóstico',
        'estado': 'Completado',
        'observaciones': 'Hígado, riñones y bazo sin anomalías',
      },
    ];
  }

  static List<Map<String, dynamic>> getRecetasMock() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'fecha': now.subtract(const Duration(days: 30)).toIso8601String(),
        'medico_nombre': 'Luis',
        'medico_apellido': 'García',
        'medicamentos': 'Losartan 50mg, Amlodipino 5mg',
        'indicaciones': 'Tomar una tableta de cada medicamento por la mañana con el desayuno',
        'dosis': '1 tableta de cada uno, una vez al día',
        'duracion': '30 días',
        'observaciones': 'Controles de presión semanales. Retornar si hay efectos secundarios',
      },
      {
        'id': 2,
        'fecha': now.subtract(const Duration(days: 15)).toIso8601String(),
        'medico_nombre': 'Elena',
        'medico_apellido': 'Martínez',
        'medicamentos': 'Ibuprofeno 400mg',
        'indicaciones': 'Tomar con alimentos, máximo 3 veces al día',
        'dosis': '1 tableta cada 8 horas si hay dolor',
        'duracion': '7 días',
        'observaciones': 'Suspender si hay molestias gástricas',
      },
      {
        'id': 3,
        'fecha': now.subtract(const Duration(days: 7)).toIso8601String(),
        'medico_nombre': 'Javier',
        'medico_apellido': 'Rodríguez',
        'medicamentos': 'Diclofenaco gel 1%, Paracetamol 500mg',
        'indicaciones': 'Aplicar gel en la zona afectada 3 veces al día. Paracetamol cada 8 horas',
        'dosis': 'Gel: 2-3 cm, Paracetamol: 1 tableta',
        'duracion': '10 días',
        'observaciones': 'Reposo relativo. Evitar esfuerzos físicos intensos',
      },
    ];
  }
}
