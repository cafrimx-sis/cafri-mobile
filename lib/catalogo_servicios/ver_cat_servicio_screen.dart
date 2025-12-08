import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cafri/catalogo_servicios/agregar_cat_servicio_screen.dart';
import 'package:cafri/catalogo_servicios/actualizar_cat_servicio_screen.dart';

// ignore_for_file: use_build_context_synchronously

class ListarServiciosScreen extends StatefulWidget {
  const ListarServiciosScreen({super.key});

  @override
  State<ListarServiciosScreen> createState() => _ListarServiciosScreenState();
}

class _ListarServiciosScreenState extends State<ListarServiciosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _borrarServicio(
    BuildContext context,
    String servicioId,
    String concepto,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "$concepto"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('servicios')
            .doc(servicioId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servicio "$concepto" eliminado exitosamente.'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar servicio: $e')),
        );
      }
    }
  }

  PopupMenuButton<String> _accionesPopup({
    required String servicioId,
    required String concepto,
    required Map<String, dynamic> data,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServicioEditarScreen(
                  servicioId: servicioId,
                  servicioData: data,
                ),
              ),
            );
            // El StreamBuilder se refresca solo
            break;
          case 'delete':
            await _borrarServicio(context, servicioId, concepto);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit, color: Colors.blue),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Eliminar'),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Color _cardTint(BuildContext context) {
    return Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de Servicios')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Búsqueda
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Buscar por código, concepto o precio',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) => setState(
                            () => _search = value.trim().toLowerCase(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('servicios')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error al cargar servicios: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _EmptyState(
                          onCreate: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServicioCreateScreen(),
                              ),
                            );
                          },
                        );
                      }

                      final allDocs = snapshot.data!.docs;
                      final servicios = allDocs.where((servicio) {
                        final data = servicio.data() as Map<String, dynamic>;
                        final codigo = (data['codigo'] ?? '')
                            .toString()
                            .toLowerCase();
                        final concepto = (data['concepto'] ?? '')
                            .toString()
                            .toLowerCase();
                        final precio = (data['precioMenudeo'] ?? '')
                            .toString()
                            .toLowerCase();
                        final id = servicio.id.toLowerCase();
                        if (_search.isEmpty) return true;
                        return codigo.contains(_search) ||
                            concepto.contains(_search) ||
                            precio.contains(_search) ||
                            id.contains(_search);
                      }).toList();

                      final total = allDocs.length;
                      final count = servicios.length;

                      if (servicios.isEmpty) {
                        return Column(
                          children: [
                            _HeaderResultados(count: 0, total: total),
                            const SizedBox(height: 12),
                            const _NoResults(),
                          ],
                        );
                      }

                      final header = _HeaderResultados(
                        count: count,
                        total: total,
                      );

                      if (isMobile) {
                        // ---------- Tarjetas para móvil ----------
                        return Column(
                          children: [
                            header,
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: servicios.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final doc = servicios[idx];
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final codigo = (data['codigo'] ?? '')
                                      .toString();
                                  final concepto = (data['concepto'] ?? '')
                                      .toString();
                                  final precio =
                                      (data['precioMenudeo'] as num?)
                                          ?.toDouble() ??
                                      0.0;

                                  return _ServicioCard(
                                    tint: _cardTint(context),
                                    codigo: codigo,
                                    concepto: concepto,
                                    precio: precio,
                                    acciones: _accionesPopup(
                                      servicioId: doc.id,
                                      concepto: concepto,
                                      data: data,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        // ---------- Tabla para escritorio/web ----------
                        return Column(
                          children: [
                            header,
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 24,
                                    headingRowColor:
                                        WidgetStatePropertyAll<Color?>(
                                          theme.colorScheme.primary.withValues(
                                            alpha: 30 / 255,
                                          ),
                                        ),
                                    columns: const [
                                      DataColumn(label: Text('Código')),
                                      DataColumn(label: Text('Concepto')),
                                      DataColumn(label: Text('Precio')),
                                      DataColumn(label: Text('Acciones')),
                                    ],
                                    rows: servicios.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final codigo = (data['codigo'] ?? '')
                                          .toString();
                                      final concepto = (data['concepto'] ?? '')
                                          .toString();
                                      final precio =
                                          (data['precioMenudeo'] as num?)
                                              ?.toDouble() ??
                                          0.0;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(codigo)),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 480,
                                              ),
                                              child: Text(
                                                concepto,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '\$${precio.toStringAsFixed(2)}',
                                            ),
                                          ),
                                          DataCell(
                                            _accionesPopup(
                                              servicioId: doc.id,
                                              concepto: concepto,
                                              data: data,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServicioCreateScreen()),
          );
        },
        tooltip: 'Agregar Servicio',
        icon: const Icon(Icons.add),
        label: const Text('Agregar Servicio'),
      ),
    );
  }
}

class _HeaderResultados extends StatelessWidget {
  final int count;
  final int total;
  const _HeaderResultados({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Mostrando $count de $total resultados',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  final String codigo;
  final String concepto;
  final double precio;
  final Color tint;
  final Widget acciones;

  const _ServicioCard({
    required this.codigo,
    required this.concepto,
    required this.precio,
    required this.tint,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tint.withValues(alpha: 0.5), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.white, tint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.6, 1],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + título + acciones
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                  foregroundColor: colorScheme.primary,
                  child: Text(
                    (codigo.isNotEmpty ? codigo[0] : '?').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$codigo - $concepto',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          'Precio: \$${precio.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                acciones,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.miscellaneous_services_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay servicios registrados.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comienza agregando tu primer servicio.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar Servicio'),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No hay resultados para la búsqueda.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
