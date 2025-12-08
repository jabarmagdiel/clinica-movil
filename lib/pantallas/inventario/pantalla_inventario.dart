import 'package:flutter/material.dart';
import '../../api.dart';

/// Pantalla principal del inventario
class PantallaInventario extends StatefulWidget {
  const PantallaInventario({Key? key}) : super(key: key);

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<dynamic> _items = [];
  List<dynamic> _categorias = [];
  String? _error;
  String? _filtroTipo;
  int? _filtroCategoria;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resultados = await Future.wait([
        ApiInventario.listarItems(
          tipo: _filtroTipo,
          categoriaId: _filtroCategoria,
          search: _searchController.text.isEmpty ? null : _searchController.text,
        ),
        ApiInventario.listarCategorias(),
      ]);

      if (!mounted) return;

      final itemsResult = resultados[0];
      final categoriasResult = resultados[1];

      if (itemsResult['ok'] == true && categoriasResult['ok'] == true) {
        setState(() {
          _items = itemsResult['data'] ?? [];
          _categorias = categoriasResult['data'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = itemsResult['error'] ?? categoriasResult['error'];
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión: $e';
        _loading = false;
      });
    }
  }

  Color _getColorPorEstado(String estado) {
    switch (estado) {
      case 'critico':
        return Colors.red;
      case 'bajo':
        return Colors.orange;
      case 'medio':
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }

  IconData _getIconoPorTipo(String tipo) {
    switch (tipo) {
      case 'medicamento':
        return Icons.medication;
      case 'suministro':
        return Icons.medical_services;
      case 'equipo':
        return Icons.monitor_heart;
      default:
        return Icons.inventory_2;
    }
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final nombre = item['nombre'] ?? '';
    final codigo = item['codigo'] ?? '';
    final cantidadActual = item['cantidad_actual'] ?? 0;
    final cantidadMinima = item['cantidad_minima'] ?? 0;
    final unidadMedida = item['unidad_medida'] ?? '';
    final tipo = item['tipo'] ?? '';
    final estadoStock = item['estado_stock'] ?? 'normal';
    final categoriaNombre = item['categoria_nombre'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorPorEstado(estadoStock).withOpacity(0.2),
          child: Icon(
            _getIconoPorTipo(tipo),
            color: _getColorPorEstado(estadoStock),
          ),
        ),
        title: Text(nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código: $codigo'),
            if (categoriaNombre != null) Text('Categoría: $categoriaNombre'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$cantidadActual $unidadMedida',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getColorPorEstado(estadoStock),
                fontSize: 16,
              ),
            ),
            Text(
              'Mín: $cantidadMinima',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItems() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay items en el inventario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildItemCard(_items[index]),
      ),
    );
  }

  Widget _buildTabAlertas() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiInventario.obtenerAlertas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data?['ok'] != true) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(snapshot.data?['error'] ?? 'Error al cargar alertas'),
              ],
            ),
          );
        }

        final data = snapshot.data!['data'];
        final totalAlertas = data['total_alertas'] ?? 0;
        final items = (data['items'] ?? []) as List;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
                const SizedBox(height: 16),
                Text(
                  'Todo el inventario está en buen estado',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[50],
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¡$totalAlertas item${totalAlertas != 1 ? 's' : ''} con stock bajo!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => _buildItemCard(items[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Items'),
            Tab(icon: Icon(Icons.warning), text: 'Alertas'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por código o nombre...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _cargarDatos(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    // TODO: Mostrar diálogo de filtros
                  },
                ),
              ],
            ),
          ),

          // Contenido con tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabItems(),
                _buildTabAlertas(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navegar a pantalla de crear item
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Función disponible solo para administradores')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Item'),
      ),
    );
  }
}
