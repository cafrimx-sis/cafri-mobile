import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardMetricasActividadesConFiltro extends StatefulWidget {
  final String? titulo;

  const DashboardMetricasActividadesConFiltro({super.key, this.titulo});

  @override
  State<DashboardMetricasActividadesConFiltro> createState() =>
      _DashboardMetricasActividadesConFiltroState();
}

class _DashboardMetricasActividadesConFiltroState
    extends State<DashboardMetricasActividadesConFiltro> {
  String _usuarioIdSeleccionado = '';
  List<Map<String, String>> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .orderBy('name')
        .get();

    setState(() {
      _usuarios = snapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'nombre': doc['name']?.toString() ?? '',
              'apellido': doc['lastName']?.toString() ?? '',
            },
          )
          .where((u) => u['nombre']!.isNotEmpty && u['apellido']!.isNotEmpty)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuarioSeleccionado = _usuarios.firstWhere(
      (u) => u['id'] == _usuarioIdSeleccionado,
      orElse: () => {},
    );

    return Scaffold(
      backgroundColor: Colors.white, // fondo sólido
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.titulo != null && widget.titulo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 7),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.indigo, size: 27),
                    const SizedBox(width: 8),
                    Text(
                      widget.titulo!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_search,
                    color: Colors.indigo,
                    size: 23,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _usuarioIdSeleccionado.isEmpty
                          ? null
                          : _usuarioIdSeleccionado,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      hint: const Text('Filtrar por usuario'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '', // '' representa TODOS
                          child: Text('Todos los usuarios'),
                        ),
                        ..._usuarios.map((usuario) {
                          return DropdownMenuItem<String>(
                            value: usuario['id'],
                            child: Text(
                              '${usuario['nombre']} ${usuario['apellido']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (usuarioId) {
                        setState(() {
                          _usuarioIdSeleccionado = usuarioId ?? '';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 7, bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle,
                    color: Colors.indigo,
                    size: 19,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _usuarioIdSeleccionado.isEmpty ||
                            usuarioSeleccionado.isEmpty
                        ? "Visualizando TODAS las actividades"
                        : "Visualizando: ${usuarioSeleccionado['nombre']} ${usuarioSeleccionado['apellido']}",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            DashboardMetricasActividades(
              nombre: usuarioSeleccionado['nombre'],
              apellido: usuarioSeleccionado['apellido'],
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardMetricasActividades extends StatelessWidget {
  final String? nombre;
  final String? apellido;
  final String? titulo;

  const DashboardMetricasActividades({
    super.key,
    this.nombre,
    this.apellido,
    this.titulo,
  });

  /// NUEVA PALETA DE COLORES MODERNA PARA LOS ESTADOS
  static const _colorPendiente = Color(0xFF42A5F5);
  static const _colorAceptada = Color(0xFF7E57C2);
  static const _colorEnProceso = Color(0xFF26C6DA);
  static const _colorPausada = Color(0xFFFFCA28);
  static const _colorTerminada = Color(0xFF66BB6A);

  Future<Map<String, int>> _contarPorEstado() async {
    Query query = FirebaseFirestore.instance.collection('actividades');
    if (nombre != null &&
        nombre!.isNotEmpty &&
        apellido != null &&
        apellido!.isNotEmpty) {
      query = query
          .where('name', isEqualTo: nombre)
          .where('lastName', isEqualTo: apellido);
    }
    final snapshot = await query.get();
    final counts = <String, int>{
      'pendiente': 0,
      'aceptada': 0,
      'en_proceso': 0,
      'pausada': 0,
      'terminada': 0,
    };
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data is Map<String, dynamic>) {
        final estado = (data['estado'] ?? 'pendiente').toString();
        if (counts.containsKey(estado)) {
          counts[estado] = (counts[estado] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _contarPorEstado(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error al cargar métricas: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final counts = snapshot.data ?? {};
        final total = counts.values.fold<int>(0, (a, b) => a + b);

        // Define estados con los nuevos colores
        final estados = [
          {'label': 'Pendientes', 'key': 'pendiente', 'color': _colorPendiente},
          {'label': 'Aceptadas', 'key': 'aceptada', 'color': _colorAceptada},
          {
            'label': 'En proceso',
            'key': 'en_proceso',
            'color': _colorEnProceso,
          },
          {'label': 'Pausadas', 'key': 'pausada', 'color': _colorPausada},
          {'label': 'Terminadas', 'key': 'terminada', 'color': _colorTerminada},
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total mini tarjeta
              Card(
                elevation: 2,
                color: _colorPendiente, // <-- Color sólido
                margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 18,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.summarize,
                        color: Colors.white, // <-- Contraste blanco para icono
                        size: 25,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Total actividades: ",
                        style: TextStyle(
                          fontSize: 17,
                          color:
                              Colors.white, // <-- Contraste blanco para texto
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "$total",
                        style: const TextStyle(
                          fontSize: 22,
                          color:
                              Colors.white, // <-- Contraste blanco para número
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Pie Chart central
              if (total > 0)
                Center(
                  child: SizedBox(
                    height: 220,
                    width: 220,
                    child: PieChart(
                      PieChartData(
                        sections: estados.map((estado) {
                          final key = estado['key'] as String;
                          final color = estado['color'] as Color?;
                          final value = counts[key] ?? 0;
                          final percent = total > 0
                              ? (value / total * 100)
                              : 0.0;
                          return PieChartSectionData(
                            color: color,
                            value: value.toDouble(),
                            title: value > 0
                                ? '${percent.toStringAsFixed(1)}%'
                                : '',
                            radius: value > 0 ? 60 : 50,
                            titleStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                ),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    children: estados.map((estado) {
                      final key = estado['key'] as String;
                      final color = estado['color'] as Color?;
                      final label = estado['label'] as String;
                      final value = counts[key] ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$label ($value)',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
              // Tarjetas de métricas (ahora con fondo sólido y texto blanco)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: estados.map((estado) {
                    final key = estado['key'] as String;
                    final label = estado['label'] as String;
                    final color = estado['color'] as Color;
                    final value = counts[key] ?? 0;
                    return _buildMetricCard(
                      label: label,
                      count: value,
                      color: color, // fondo sólido
                      icon: _iconForEstado(key),
                      bgColor: color, // fondo sólido
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForEstado(String key) {
    switch (key) {
      case 'pendiente':
        return Icons.hourglass_empty;
      case 'aceptada':
        return Icons.check_circle_outline;
      case 'en_proceso':
        return Icons.play_circle_outline;
      case 'pausada':
        return Icons.pause_circle_outline;
      case 'terminada':
        return Icons.verified;
      default:
        return Icons.analytics;
    }
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required Color bgColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Card(
        elevation: 6,
        color: bgColor, // fondo sólido
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ), // Blanco para contraste
              const SizedBox(height: 6),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Blanco para contraste
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white, // Blanco para contraste
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
