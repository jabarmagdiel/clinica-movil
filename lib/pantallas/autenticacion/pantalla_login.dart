import 'package:flutter/material.dart';
import '../../api.dart';
import '../../servicios/servicio_notificaciones.dart';
import 'pantalla_registro.dart';
import '../principal/pantalla_principal.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
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
      // Registrar dispositivo para notificaciones push después del login
      await ServicioNotificaciones.registrarDispositivoDespuesLogin();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Bienvenido!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PantallaPrincipal()),
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
                                MaterialPageRoute(builder: (_) => const PantallaRegistro()),
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
