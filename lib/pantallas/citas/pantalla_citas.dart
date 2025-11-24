import 'package:flutter/material.dart';
import '../../api.dart';
import 'widgets/selector_horas.dart';

class PantallaCitas extends StatefulWidget {
  const PantallaCitas({super.key});

  @override
  State<PantallaCitas> createState() => _PantallaCitasState();
}

class _PantallaCitasState extends State<PantallaCitas> {
  bool loadingSelect = true;
  bool loadingHoras = false;
  bool saving = false;

  List<Map<String, dynamic>> medEsp = [];
  int? selectedMedEspId;

  DateTime? selectedDate;
  String? selectedHora;

  List<String> horas = [];

  int? pacienteId;

  // Mis citas
  bool loadingCitas = true;
  List<Map<String, dynamic>> misCitas = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // paciente
    final me = await ApiCitas.meLocal();
    pacienteId = me?['id'];

    // medico-especialidades
    final sel = await ApiCitas.medicoEspecialidades();
    if (sel['ok'] == true) {
      medEsp =
          (sel['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }

    // mis citas
    await _cargarMisCitas();

    setState(() => loadingSelect = false);
  }

  Future<void> _cargarMisCitas() async {
    setState(() => loadingCitas = true);
    final res = await ApiCitas.listar();
    if (res['ok'] == true) {
      final list =
      (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      // filtra por mi pacienteId si viene en la respuesta
      if (pacienteId != null) {
        misCitas = list.where((c) {
          final pid = c['paciente'] ?? c['paciente_id'];
          return pid == pacienteId;
        }).toList();
      } else {
        misCitas = list;
      }
    }
    setState(() => loadingCitas = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: selectedDate ?? now,
    );
    if (d != null) {
      setState(() {
        selectedDate = d;
        selectedHora = null;
        horas.clear();
      });
      await _loadHoras();
    }
  }

  Future<void> _loadHoras() async {
    if (selectedMedEspId == null || selectedDate == null) return;
    setState(() => loadingHoras = true);
    final fecha = _fmtDate(selectedDate!);
    final res = await ApiCitas.horasDisponibles(
      medicoEspecialidadId: selectedMedEspId!,
      fecha: fecha,
    );
    if (res['ok'] == true) {
      setState(() => horas = (res['data'] as List<String>));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'].toString())),
        );
      }
    }
    setState(() => loadingHoras = false);
  }

  Future<void> _crearCita() async {
    if (pacienteId == null ||
        selectedMedEspId == null ||
        selectedDate == null ||
        selectedHora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa médico, fecha y hora.')),
      );
      return;
    }
    setState(() => saving = true);
    final res = await ApiCitas.crear(
      pacienteId: pacienteId!,
      medicoEspecialidadId: selectedMedEspId!,
      fechaCita: _fmtDate(selectedDate!),
      horaCita: selectedHora!,
    );
    setState(() => saving = false);

    if (res['ok'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita creada con éxito')),
      );
      // limpiar selección y recargar
      setState(() {
        selectedHora = null;
        horas.clear();
      });
      await _cargarMisCitas();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'].toString())),
      );
    }
  }

  Future<void> _editarCita(Map<String, dynamic> cita) async {
    final fecha0 =
        (cita['fecha_cita'] as String?)?.split('T').first ?? _fmtDate(DateTime.now());
    final hora0 = (cita['hora_cita'] as String?) ?? '08:00';

    DateTime? newDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDate: DateTime.tryParse(fecha0) ?? DateTime.now(),
    );
    if (newDate == null) return;

    // horas disponibles para el mismo médico-especialidad de la cita
    final medEspId = cita['medico_especialidad'] as int? ?? selectedMedEspId;
    if (medEspId == null) return;

    final horasRes = await ApiCitas.horasDisponibles(
      medicoEspecialidadId: medEspId,
      fecha: _fmtDate(newDate),
    );
    if (horasRes['ok'] != true) return;

    final nuevaHora = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SelectorHoras(horas: (horasRes['data'] as List<String>), pre: hora0),
    );
    if (nuevaHora == null) return;

    final res = await ApiCitas.actualizar(
      citaId: (cita['id'] as int),
      fechaCita: _fmtDate(newDate),
      horaCita: nuevaHora,
    );
    if (res['ok'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita actualizada')),
      );
      await _cargarMisCitas();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'].toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Citas médicas')),
      body: loadingSelect
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await _cargarMisCitas();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Nueva cita', style: text.titleLarge),
            const SizedBox(height: 12),

            // Médico–especialidad
            DropdownButtonFormField<int>(
              value: selectedMedEspId,
              decoration: const InputDecoration(
                labelText: 'Médico – Especialidad',
                prefixIcon: Icon(Icons.local_hospital),
              ),
              items: medEsp.map((m) {
                final label =
                    '${m['medico_nombre_completo']}  ·  ${m['especialidad_nombre']}';
                return DropdownMenuItem<int>(
                  value: m['id'] as int,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (v) async {
                setState(() {
                  selectedMedEspId = v;
                  horas.clear();
                  selectedHora = null;
                });
                await _loadHoras();
              },
            ),

            const SizedBox(height: 12),

            // Fecha
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: selectedDate != null ? _fmtDate(selectedDate!) : '',
              ),
              decoration: InputDecoration(
                labelText: 'Fecha',
                prefixIcon: const Icon(Icons.event),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickDate,
                ),
              ),
              onTap: _pickDate,
            ),

            const SizedBox(height: 12),

            // Horas disponibles
            if (loadingHoras)
              const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ))
            else if (horas.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: horas.map((h) {
                  final sel = selectedHora == h;
                  return ChoiceChip(
                    label: Text(h),
                    selected: sel,
                    onSelected: (_) => setState(() => selectedHora = h),
                  );
                }).toList(),
              )
            else
              const Text('Selecciona médico y fecha para ver horas.'),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: saving ? null : _crearCita,
              icon: const Icon(Icons.check),
              label: Text(saving ? 'Guardando...' : 'Confirmar cita'),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            Text('Mis citas', style: text.titleLarge),
            const SizedBox(height: 8),

            if (loadingCitas)
              const Center(child: CircularProgressIndicator())
            else if (misCitas.isEmpty)
              const Text('No tienes citas registradas.')
            else
              ...misCitas.map((c) => Card(
                child: ListTile(
                  leading: const Icon(Icons.event_available),
                  title: Text(
                      '${c['especialidad_nombre'] ?? ''} — ${c['medico_nombre'] ?? ''} ${c['medico_apellido'] ?? ''}'),
                  subtitle: Text(
                      'Fecha: ${c['fecha_cita']?.toString().split('T').first ?? ''}  •  Hora: ${c['hora_cita'] ?? ''}\nEstado: ${c['estado'] ?? ''}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editarCita(c),
                    tooltip: 'Cambiar fecha/hora',
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
