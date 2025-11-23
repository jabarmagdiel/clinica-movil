// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'api.dart';

void main() {
  runApp(const ClinicaApp());
}

class ClinicaApp extends StatelessWidget {
  const ClinicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clínica',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

/// AuthGate considera logueado si hay token.
/// Si existe /api/me/ lo usa; si falla, usa el "user" guardado en el login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool logged = false;
  Map<String, dynamic>? me;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // 1) si hay token damos por logueado
    final token = await storage.read(key: 'access');
    if (token != null) {
      // 2) intentamos /api/me/
      try {
        final res = await ApiAuth.me();
        if (res['ok'] == true) {
          me = res['data'];
        } else {
          // 3) respaldo: user guardado en el login
          me = await ApiAuth.getStoredUser();
        }
      } catch (_) {
        me = await ApiAuth.getStoredUser();
      }
      setState(() {
        loading = false;
        logged = true;
      });
      return;
    }

    // sin token -> no logueado
    setState(() {
      loading = false;
      logged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return logged ? HomeScreen(me: me) : const LoginScreen();
  }
}

// =================== LOGIN MODERNO ===================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPass = false;
  bool loading = false;
  String? serverError;

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => serverError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    final res = await ApiAuth.login(
      email: userCtrl.text.trim(),
      password: passCtrl.text,
    );
    setState(() => loading = false);

    if (!mounted) return;
    if (res['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Bienvenido!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } else {
      setState(() => serverError = (res['error'] ?? 'Error desconocido').toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 700;
            final content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo + título
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: cs.primaryContainer,
                            child: Icon(Icons.local_hospital, color: cs.onPrimaryContainer, size: 30),
                          ),
                          const SizedBox(height: 12),
                          Text('Iniciar sesión',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 4),
                          Text('Accede a tu panel de paciente',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              )),
                          const SizedBox(height: 20),

                          // Usuario/Email
                          TextFormField(
                            controller: userCtrl,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Correo o usuario',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu correo o usuario';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Contraseña
                          TextFormField(
                            controller: passCtrl,
                            obscureText: !showPass,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onEditingComplete: _submit,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                tooltip: showPass ? 'Ocultar' : 'Mostrar',
                                icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => showPass = !showPass),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                              if (v.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),

                          if (serverError != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.error_outline, color: cs.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    serverError!,
                                    style: TextStyle(color: cs.error),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: loading ? null : _submit,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(loading ? 'Ingresando…' : 'Entrar'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Text('Crear cuenta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Fondo con gradiente sutil
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primaryContainer.withOpacity(.35),
                        cs.surface,
                      ],
                    ),
                  ),
                ),
                if (wide)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Clínica',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                    ),
                  ),
                content,
              ],
            );
          },
        ),
      ),
    );
  }
}


// =================== REGISTRO ===================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nombreCtrl = TextEditingController();
  final apellidoCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? msg;

  Future<void> _doRegister() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      msg = null;
    });

    final res = await ApiAuth.registerPaciente(
      email: emailCtrl.text.trim(),
      password: passCtrl.text,
      nombre: nombreCtrl.text.trim(),
      apellido: apellidoCtrl.text.trim(),
      telefono: telCtrl.text.trim(),
    );

    setState(() => loading = false);

    if (!mounted) return;

    if (res['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Ahora inicia sesión.')),
      );

      // 🔁 Redirigir al LoginScreen después de 1 segundo
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      });
    } else {
      final err = res['error'] ?? 'Error al registrarse';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      setState(() => msg = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Paciente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre', prefixIcon: Icon(Icons.badge))),
            const SizedBox(height: 8),
            TextField(
                controller: apellidoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Apellido',
                    prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 8),
            TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Correo', prefixIcon: Icon(Icons.mail))),
            const SizedBox(height: 8),
            TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 8),
            TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña', prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: loading ? null : _doRegister,
                child: Text(loading ? 'Guardando...' : 'Registrarse')),
            if (msg != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(msg!)),
          ],
        ),
      ),
    );
  }
}

// =================== HOME ===================
class HomeScreen extends StatelessWidget {
  final Map<String, dynamic>? me;
  const HomeScreen({super.key, this.me});

  String _displayName() {
    final nombre = (me?['nombre'] ?? '').toString().trim();
    final apellido = (me?['apellido'] ?? '').toString().trim();
    if (nombre.isNotEmpty || apellido.isNotEmpty) {
      return [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
    }
    return me?['username'] ?? me?['email'] ?? 'Paciente';
  }

  @override
  Widget build(BuildContext context) {
    final user = _displayName();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("¡Bienvenido, $user!",
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle,
                    size: 40, color: Colors.indigo),
                title: Text(user),
                subtitle: const Text("Paciente registrado"),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _HomeOption(
                    icon: Icons.calendar_month,
                    label: "Citas médicas",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CitasScreen())),
                  ),
                  _HomeOption(
                    icon: Icons.search,
                    label: "Buscar médico",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuscarMedicoScreen())),
                  ),
                  _HomeOption(
                    icon: Icons.history,
                    label: "Historia clínica",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriaClinicaScreen())),
                  ),
                  _HomeOption(
                    icon: Icons.assignment,
                    label: "Consentimientos",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsentimientosScreen())),
                  ),
                  _HomeOption(
                    icon: Icons.person,
                    label: "Mi perfil",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
                  ),
                ],


              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text('Menú',
                  style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                await ApiAuth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                        (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _HomeOption({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.indigo),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/main.dart (debajo de tus otros widgets)
class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
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
      builder: (_) => _HorasSheet(horas: (horasRes['data'] as List<String>), pre: hora0),
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

class _HorasSheet extends StatelessWidget {
  final List<String> horas;
  final String? pre;
  const _HorasSheet({required this.horas, this.pre});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: horas.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final h = horas[i];
          return ListTile(
            title: Text(h),
            trailing: pre == h ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(h),
          );
        },
      ),
    );
  }
}

class BuscarMedicoScreen extends StatefulWidget {
  const BuscarMedicoScreen({super.key});

  @override
  State<BuscarMedicoScreen> createState() => _BuscarMedicoScreenState();
}

class _BuscarMedicoScreenState extends State<BuscarMedicoScreen> {
  bool loading = true;
  List<Map<String, dynamic>> medEsp = [];
  List<Map<String, dynamic>> filtrado = [];
  int? especialidadId;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiMedicos.medicoEspecialidades();
    if (res['ok'] == true) {
      medEsp = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      _aplicarFiltros();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'].toString())),
        );
      }
    }
    setState(() => loading = false);
  }

  void _aplicarFiltros() {
    setState(() {
      filtrado = medEsp.where((m) {
        final okEsp = especialidadId == null || m['especialidad'] == especialidadId;
        final nombre = (m['medico_nombre_completo'] ?? '').toString().toLowerCase();
        final okQ = query.isEmpty || nombre.contains(query.toLowerCase());
        return okEsp && okQ;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final especialidades = {
      for (final m in medEsp) m['especialidad']: m['especialidad_nombre']
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar médico')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: especialidadId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas las especialidades')),
                      ...especialidades.entries.map((e) => DropdownMenuItem<int>(
                        value: e.key as int,
                        child: Text(e.value.toString()),
                      )),
                    ],
                    onChanged: (v) {
                      especialidadId = v;
                      _aplicarFiltros();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Especialidad',
                      prefixIcon: Icon(Icons.local_hospital),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (t) {
                      query = t;
                      _aplicarFiltros();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Buscar médico',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtrado.isEmpty
                ? const Center(child: Text('No hay resultados'))
                : ListView.separated(
              itemCount: filtrado.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = filtrado[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(m['medico_nombre_completo'] ?? ''),
                  subtitle: Text(m['especialidad_nombre'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(m['medico_nombre_completo'] ?? ''),
                        content: Text('Especialidad: ${m['especialidad_nombre'] ?? ''}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool loading = true;
  bool saving = false;

  final nombreCtrl = TextEditingController();
  final apellidoCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiPerfil.obtener();
    if (res['ok'] == true) {
      final u = Map<String, dynamic>.from(res['data']);
      nombreCtrl.text = (u['nombre'] ?? '').toString();
      apellidoCtrl.text = (u['apellido'] ?? '').toString();
      telCtrl.text = (u['telefono'] ?? '').toString();
      emailCtrl.text = (u['email'] ?? '').toString();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'].toString())),
        );
      }
    }
    setState(() => loading = false);
  }

  Future<void> _guardar() async {
    setState(() => saving = true);
    final res = await ApiPerfil.actualizar(
      nombre: nombreCtrl.text.trim(),
      apellido: apellidoCtrl.text.trim(),
      telefono: telCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      password: passCtrl.text.isNotEmpty ? passCtrl.text : null,
    );
    setState(() => saving = false);
    if (res['ok'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      Navigator.pop(context); // vuelve atrás
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'].toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: apellidoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellido',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña (opcional)',
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : _guardar,
              icon: const Icon(Icons.save),
              label: Text(saving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== HISTORIA CLÍNICA ===================
class HistoriaClinicaScreen extends StatefulWidget {
  const HistoriaClinicaScreen({super.key});

  @override
  State<HistoriaClinicaScreen> createState() => _HistoriaClinicaScreenState();
}

class _HistoriaClinicaScreenState extends State<HistoriaClinicaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool loading = true;
  bool loadingPdf = false;

  // Filtros
  DateTime? fechaDesde;
  DateTime? fechaHasta;
  int? medicoId;
  List<Map<String, dynamic>> medicos = [];

  // Datos
  List<Map<String, dynamic>> consultas = [];
  List<Map<String, dynamic>> examenes = [];
  List<Map<String, dynamic>> recetas = [];

  // Paginación
  int currentPageConsultas = 1;
  int currentPageExamenes = 1;
  int currentPageRecetas = 1;
  bool hasMoreConsultas = true;
  bool hasMoreExamenes = true;
  bool hasMoreRecetas = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarMedicos() async {
    final res = await ApiMedicos.medicoEspecialidades();
    if (res['ok'] == true) {
      final lista = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        medicos = lista;
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<void> _cargarDatos() async {
    setState(() => loading = true);
    await _cargarMedicos();
    await Future.wait([
      _cargarConsultas(),
      _cargarExamenes(),
      _cargarRecetas(),
    ]);
    setState(() => loading = false);
  }

  Future<void> _cargarConsultas({bool reset = false}) async {
    if (reset) {
      currentPageConsultas = 1;
      consultas.clear();
    }
    final res = await ApiHistoriaClinica.listarConsultas(
      fechaDesde: fechaDesde != null ? _fmtDate(fechaDesde) : null,
      fechaHasta: fechaHasta != null ? _fmtDate(fechaHasta) : null,
      medicoId: medicoId,
      page: currentPageConsultas,
    );
    if (res['ok'] == true) {
      final nuevaLista = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        consultas = reset ? nuevaLista : [...consultas, ...nuevaLista];
        hasMoreConsultas = res['next'] != null;
      });
    } else if (consultas.isEmpty && reset) {
      // Si no hay datos del backend y es la primera carga, agregar datos de ejemplo
      setState(() {
        consultas = _getConsultasMock();
      });
    }
  }

  List<Map<String, dynamic>> _getConsultasMock() {
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

  Future<void> _cargarExamenes({bool reset = false}) async {
    if (reset) {
      currentPageExamenes = 1;
      examenes.clear();
    }
    final res = await ApiHistoriaClinica.listarExamenes(
      fechaDesde: fechaDesde != null ? _fmtDate(fechaDesde) : null,
      fechaHasta: fechaHasta != null ? _fmtDate(fechaHasta) : null,
      medicoId: medicoId,
      page: currentPageExamenes,
    );
    if (res['ok'] == true) {
      final nuevaLista = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        examenes = reset ? nuevaLista : [...examenes, ...nuevaLista];
        hasMoreExamenes = res['next'] != null;
      });
    } else if (examenes.isEmpty && reset) {
      // Si no hay datos del backend y es la primera carga, agregar datos de ejemplo
      setState(() {
        examenes = _getExamenesMock();
      });
    }
  }

  List<Map<String, dynamic>> _getExamenesMock() {
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

  Future<void> _cargarRecetas({bool reset = false}) async {
    if (reset) {
      currentPageRecetas = 1;
      recetas.clear();
    }
    final res = await ApiHistoriaClinica.listarRecetas(
      fechaDesde: fechaDesde != null ? _fmtDate(fechaDesde) : null,
      fechaHasta: fechaHasta != null ? _fmtDate(fechaHasta) : null,
      medicoId: medicoId,
      page: currentPageRecetas,
    );
    if (res['ok'] == true) {
      final nuevaLista = (res['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        recetas = reset ? nuevaLista : [...recetas, ...nuevaLista];
        hasMoreRecetas = res['next'] != null;
      });
    } else if (recetas.isEmpty && reset) {
      // Si no hay datos del backend y es la primera carga, agregar datos de ejemplo
      setState(() {
        recetas = _getRecetasMock();
      });
    }
  }

  List<Map<String, dynamic>> _getRecetasMock() {
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

  Future<void> _aplicarFiltros() async {
    setState(() => loading = true);
    await Future.wait([
      _cargarConsultas(reset: true),
      _cargarExamenes(reset: true),
      _cargarRecetas(reset: true),
    ]);
    setState(() => loading = false);
    Navigator.pop(context); // Cierra el diálogo de filtros
  }

  Future<void> _mostrarFiltros() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtros'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Fecha desde'),
                  subtitle: Text(fechaDesde != null ? _fmtDate(fechaDesde) : 'Seleccionar'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: fechaDesde ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setDialogState(() => fechaDesde = d);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Fecha hasta'),
                  subtitle: Text(fechaHasta != null ? _fmtDate(fechaHasta) : 'Seleccionar'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: fechaHasta ?? DateTime.now(),
                      firstDate: fechaDesde ?? DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setDialogState(() => fechaHasta = d);
                    }
                  },
                ),
                DropdownButtonFormField<int>(
                  value: medicoId,
                  decoration: const InputDecoration(labelText: 'Médico'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...medicos.map((m) => DropdownMenuItem<int>(
                      value: m['medico'] as int?,
                      child: Text(m['medico_nombre_completo'] ?? ''),
                    )),
                  ],
                  onChanged: (v) => setDialogState(() => medicoId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  fechaDesde = null;
                  fechaHasta = null;
                  medicoId = null;
                });
                Navigator.pop(context);
                _aplicarFiltros();
              },
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _aplicarFiltros,
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _descargarPdf() async {
    setState(() => loadingPdf = true);
    try {
      // Primero intenta descargar desde el backend
      final res = await ApiHistoriaClinica.descargarPdf(
        fechaDesde: fechaDesde != null ? _fmtDate(fechaDesde) : null,
        fechaHasta: fechaHasta != null ? _fmtDate(fechaHasta) : null,
        medicoId: medicoId,
      );

      if (res['ok'] == true && res['data'] != null) {
        final bytes = res['data'] as List<int>;
        
        // Usar printing para mostrar/guardar el PDF
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => Uint8List.fromList(bytes),
            name: 'Historia_Clinica.pdf',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF descargado exitosamente')),
            );
          }
        } catch (e) {
          // Si printing falla, intentar con share_plus
          if (!kIsWeb) {
            try {
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/historia_clinica.pdf');
              await file.writeAsBytes(bytes);
              
              await Share.shareXFiles(
                [XFile(file.path)],
                text: 'Mi Historia Clínica',
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF descargado y compartido')),
                );
              }
            } catch (e2) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al compartir PDF: $e2')),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF descargado. Usa el botón de imprimir/guardar del visor.')),
              );
            }
          }
        }
      } else {
        // Si el backend no tiene PDF, generamos uno localmente
        await _generarPdfLocal();
      }
    } catch (e) {
      // Si falla, intentamos generar PDF local
      try {
        await _generarPdfLocal();
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar PDF: $e2')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => loadingPdf = false);
      }
    }
  }

  Future<void> _generarPdfLocal() async {
    try {
      // Obtener datos completos
      final historiaRes = await ApiHistoriaClinica.obtenerHistoriaCompleta(
        fechaDesde: fechaDesde != null ? _fmtDate(fechaDesde) : null,
        fechaHasta: fechaHasta != null ? _fmtDate(fechaHasta) : null,
        medicoId: medicoId,
      );

      final data = historiaRes['ok'] == true ? historiaRes['data'] as Map<String, dynamic>? : null;
      final user = await ApiAuth.getStoredUser();
      final nombrePaciente = '${user?['nombre'] ?? ''} ${user?['apellido'] ?? ''}'.trim();
      
      final consultasData = data != null ? (data['consultas'] as List?) ?? [] : consultas;
      final examenesData = data != null ? (data['examenes'] as List?) ?? [] : examenes;
      final recetasData = data != null ? (data['recetas'] as List?) ?? [] : recetas;

      await _generarPdfConDatos(consultasData, examenesData, recetasData, nombrePaciente);
    } catch (e) {
      await _generarPdfConDatos(consultas, examenes, recetas, '');
    }
  }

  Future<void> _generarPdfConDatos(
    List<dynamic> consultasData,
    List<dynamic> examenesData,
    List<dynamic> recetasData,
    String nombrePaciente,
  ) async {
    try {
      final user = await ApiAuth.getStoredUser();
      final paciente = nombrePaciente.isEmpty 
          ? '${user?['nombre'] ?? ''} ${user?['apellido'] ?? ''}'.trim()
          : nombrePaciente;

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('HISTORIA CLÍNICA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Paciente: $paciente', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 30),
              
              // Consultas
              if (consultasData.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('CONSULTAS MÉDICAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                ...consultasData.map((c) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Fecha: ${c['fecha']?.toString().split('T').first ?? c['fecha_consulta']?.toString().split('T').first ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Médico: ${c['medico_nombre'] ?? ''} ${c['medico_apellido'] ?? ''}'),
                      if (c['especialidad_nombre'] != null || c['especialidad'] != null) 
                        pw.Text('Especialidad: ${c['especialidad_nombre'] ?? c['especialidad'] ?? ''}'),
                      if (c['diagnostico'] != null || c['diagnostico_consulta'] != null) 
                        pw.Text('Diagnóstico: ${c['diagnostico'] ?? c['diagnostico_consulta'] ?? ''}'),
                      if (c['motivo'] != null || c['motivo_consulta'] != null) 
                        pw.Text('Motivo: ${c['motivo'] ?? c['motivo_consulta'] ?? ''}'),
                      if (c['observaciones'] != null) 
                        pw.Text('Observaciones: ${c['observaciones']}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                      if (c['sintomas'] != null) 
                        pw.Text('Síntomas: ${c['sintomas']}'),
                    ],
                  ),
                )),
                pw.SizedBox(height: 20),
              ],

              // Exámenes
              if (examenesData.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('EXÁMENES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                ...examenesData.map((e) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Tipo: ${e['tipo_examen'] ?? e['nombre'] ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Fecha: ${e['fecha']?.toString().split('T').first ?? e['fecha_examen']?.toString().split('T').first ?? 'N/A'}'),
                      if (e['medico_nombre'] != null) 
                        pw.Text('Médico: ${e['medico_nombre']} ${e['medico_apellido'] ?? ''}'),
                      if (e['resultado'] != null || e['resultados'] != null) 
                        pw.Text('Resultado: ${e['resultado'] ?? e['resultados'] ?? ''}'),
                      if (e['laboratorio'] != null) 
                        pw.Text('Laboratorio: ${e['laboratorio']}'),
                      if (e['observaciones'] != null) 
                        pw.Text('Observaciones: ${e['observaciones']}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                      if (e['estado'] != null) 
                        pw.Text('Estado: ${e['estado']}'),
                    ],
                  ),
                )),
                pw.SizedBox(height: 20),
              ],

              // Recetas
              if (recetasData.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('RECETAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                ...recetasData.map((r) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Fecha: ${r['fecha']?.toString().split('T').first ?? r['fecha_receta']?.toString().split('T').first ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (r['medico_nombre'] != null) 
                        pw.Text('Médico: ${r['medico_nombre']} ${r['medico_apellido'] ?? ''}'),
                      if (r['medicamentos'] != null || r['medicamento'] != null) 
                        pw.Text('Medicamentos: ${r['medicamentos'] ?? r['medicamento'] ?? ''}'),
                      if (r['indicaciones'] != null || r['instrucciones'] != null) 
                        pw.Text('Indicaciones: ${r['indicaciones'] ?? r['instrucciones'] ?? ''}'),
                      if (r['dosis'] != null) 
                        pw.Text('Dosis: ${r['dosis']}'),
                      if (r['duracion'] != null) 
                        pw.Text('Duración: ${r['duracion']}'),
                      if (r['observaciones'] != null) 
                        pw.Text('Observaciones: ${r['observaciones']}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                )),
              ],
            ];
          },
        ),
      );

      // Guardar y compartir usando printing (funciona en todas las plataformas)
      final bytes = await pdf.save();
      final pdfBytes = Uint8List.fromList(bytes);
      
      // Intentar compartir directamente usando printing
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Historia_Clinica_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generado exitosamente')),
          );
        }
      } catch (e) {
        // Si printing falla, intentar con share_plus
        try {
          if (!kIsWeb) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/historia_clinica_${DateTime.now().millisecondsSinceEpoch}.pdf');
            await file.writeAsBytes(bytes);
            
            await Share.shareXFiles(
              [XFile(file.path)],
              text: 'Mi Historia Clínica',
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF generado y compartido')),
              );
            }
          } else {
            // En web, usar printing directamente
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdfBytes,
            );
          }
        } catch (e2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al compartir PDF: $e2')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    }
  }

  Widget _buildListaConsultas() {
    if (loading && consultas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (consultas.isEmpty) {
      return const Center(child: Text('No hay consultas registradas'));
    }
    return RefreshIndicator(
      onRefresh: () => _cargarConsultas(reset: true),
      child: ListView.builder(
        itemCount: consultas.length + (hasMoreConsultas ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == consultas.length) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    currentPageConsultas++;
                    _cargarConsultas();
                  },
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

  Widget _buildListaExamenes() {
    if (loading && examenes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (examenes.isEmpty) {
      return const Center(child: Text('No hay exámenes registrados'));
    }
    return RefreshIndicator(
      onRefresh: () => _cargarExamenes(reset: true),
      child: ListView.builder(
        itemCount: examenes.length + (hasMoreExamenes ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == examenes.length) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    currentPageExamenes++;
                    _cargarExamenes();
                  },
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

  Widget _buildListaRecetas() {
    if (loading && recetas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recetas.isEmpty) {
      return const Center(child: Text('No hay recetas registradas'));
    }
    return RefreshIndicator(
      onRefresh: () => _cargarRecetas(reset: true),
      child: ListView.builder(
        itemCount: recetas.length + (hasMoreRecetas ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == recetas.length) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    currentPageRecetas++;
                    _cargarRecetas();
                  },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia Clínica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _mostrarFiltros,
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: loadingPdf ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ) : const Icon(Icons.download),
            onPressed: loadingPdf ? null : _descargarPdf,
            tooltip: 'Descargar PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Consultas', icon: Icon(Icons.medical_services)),
            Tab(text: 'Exámenes', icon: Icon(Icons.science)),
            Tab(text: 'Recetas', icon: Icon(Icons.medication)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaConsultas(),
          _buildListaExamenes(),
          _buildListaRecetas(),
        ],
      ),
    );
  }
}

// =================== CONSENTIMIENTOS ===================
class ConsentimientosScreen extends StatefulWidget {
  const ConsentimientosScreen({super.key});

  @override
  State<ConsentimientosScreen> createState() => _ConsentimientosScreenState();
}

class _ConsentimientosScreenState extends State<ConsentimientosScreen> {
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
