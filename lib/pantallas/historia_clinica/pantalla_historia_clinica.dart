import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api.dart';
import 'widgets/lista_consultas.dart';
import 'widgets/lista_examenes.dart';
import 'widgets/lista_recetas.dart';
import 'servicios/generador_pdf.dart';
import 'servicios/datos_mock.dart';

class PantallaHistoriaClinica extends StatefulWidget {
  const PantallaHistoriaClinica({super.key});

  @override
  State<PantallaHistoriaClinica> createState() => _PantallaHistoriaClinicaState();
}

class _PantallaHistoriaClinicaState extends State<PantallaHistoriaClinica> with SingleTickerProviderStateMixin {
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
      setState(() {
        consultas = DatosMock.getConsultasMock();
      });
    }
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
      setState(() {
        examenes = DatosMock.getExamenesMock();
      });
    }
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
      setState(() {
        recetas = DatosMock.getRecetasMock();
      });
    }
  }

  Future<void> _aplicarFiltros() async {
    setState(() => loading = true);
    await Future.wait([
      _cargarConsultas(reset: true),
      _cargarExamenes(reset: true),
      _cargarRecetas(reset: true),
    ]);
    setState(() => loading = false);
    Navigator.pop(context);
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
      final generador = GeneradorPdf();
      await generador.generarYCompartirPdf(
        consultas: consultas,
        examenes: examenes,
        recetas: recetas,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
        medicoId: medicoId,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loadingPdf = false);
      }
    }
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
          ListaConsultas(
            consultas: consultas,
            loading: loading,
            hasMore: hasMoreConsultas,
            onCargarMas: () {
              currentPageConsultas++;
              _cargarConsultas();
            },
            onRefresh: () => _cargarConsultas(reset: true),
          ),
          ListaExamenes(
            examenes: examenes,
            loading: loading,
            hasMore: hasMoreExamenes,
            onCargarMas: () {
              currentPageExamenes++;
              _cargarExamenes();
            },
            onRefresh: () => _cargarExamenes(reset: true),
          ),
          ListaRecetas(
            recetas: recetas,
            loading: loading,
            hasMore: hasMoreRecetas,
            onCargarMas: () {
              currentPageRecetas++;
              _cargarRecetas();
            },
            onRefresh: () => _cargarRecetas(reset: true),
          ),
        ],
      ),
    );
  }
}
