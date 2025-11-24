import 'package:flutter/material.dart';
import '../../api.dart';
import 'pantalla_login.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});
  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
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

      // Redirigir al LoginScreen después de 1 segundo
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaLogin()),
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
