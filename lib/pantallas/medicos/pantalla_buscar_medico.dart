import 'package:flutter/material.dart';
import '../../api.dart';

class PantallaBuscarMedico extends StatefulWidget {
  const PantallaBuscarMedico({super.key});

  @override
  State<PantallaBuscarMedico> createState() => _PantallaBuscarMedicoState();
}

class _PantallaBuscarMedicoState extends State<PantallaBuscarMedico> {
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
