import 'package:flutter/material.dart';
import '../../api.dart';
import '../citas/pantalla_citas.dart';
import '../medicos/pantalla_buscar_medico.dart';
import '../historia_clinica/pantalla_historia_clinica.dart';
import '../consentimientos/pantalla_consentimientos.dart';
import '../perfil/pantalla_perfil.dart';
import '../notificaciones/pantalla_notificaciones.dart';
import '../autenticacion/pantalla_login.dart';

class PantallaPrincipal extends StatelessWidget {
  final Map<String, dynamic>? me;
  const PantallaPrincipal({super.key, this.me});

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
                  _OpcionPrincipal(
                    icon: Icons.calendar_month,
                    label: "Citas médicas",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaCitas())),
                  ),
                  _OpcionPrincipal(
                    icon: Icons.search,
                    label: "Buscar médico",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaBuscarMedico())),
                  ),
                  _OpcionPrincipal(
                    icon: Icons.history,
                    label: "Historia clínica",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaHistoriaClinica())),
                  ),
                  _OpcionPrincipal(
                    icon: Icons.assignment,
                    label: "Consentimientos",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaConsentimientos())),
                  ),
                  _OpcionPrincipal(
                    icon: Icons.notifications,
                    label: "Notificaciones",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaNotificaciones())),
                  ),
                  _OpcionPrincipal(
                    icon: Icons.person,
                    label: "Mi perfil",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaPerfil())),
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
                    MaterialPageRoute(builder: (_) => const PantallaLogin()),
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

class _OpcionPrincipal extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _OpcionPrincipal({required this.icon, required this.label, this.onTap});

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
