import 'package:flutter/material.dart';
import '../../api.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});
  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
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
