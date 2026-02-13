// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo para los productos/servicios de la cotización
class CotizacionItem {
  final String codigo;
  final String descripcion;
  final int cantidad;
  final double precio;
  final double impuesto; // Ej. 0.16 para 16%, -0.16 para -16%, 0.0 para 0%

  CotizacionItem({
    required this.codigo,
    required this.descripcion,
    required this.cantidad,
    required this.precio,
    required this.impuesto,
  });

  double get subtotal => cantidad * precio;
  double get total => subtotal * (1 + impuesto);

  CotizacionItem copyWith({
    String? codigo,
    String? descripcion,
    int? cantidad,
    double? precio,
    double? impuesto,
  }) {
    return CotizacionItem(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      precio: precio ?? this.precio,
      impuesto: impuesto ?? this.impuesto,
    );
  }
}

class Cliente {
  final String id;
  final String codigo;
  final String nombre;
  final String email;
  final String direccion;
  final String ciudad;
  final String telefono;

  Cliente({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.email,
    required this.direccion,
    required this.ciudad,
    required this.telefono,
  });

  factory Cliente.fromFirestore(String id, Map<String, dynamic> data) {
    return Cliente(
      id: id,
      codigo: data['codigo'] ?? '',
      nombre: data['nombre'] ?? '',
      email: data['correo'] ?? '',
      direccion: data['direccion'] ?? '',
      ciudad: data['ciudad'] ?? '',
      telefono: data['telefono'] ?? '',
    );
  }
}

class CotizacionScreen extends StatefulWidget {
  const CotizacionScreen({super.key});

  @override
  State<CotizacionScreen> createState() => _CotizacionScreenState();
}

class _CotizacionScreenState extends State<CotizacionScreen> {
  // clave de borrador en storage
  static const String _draftKey = 'cotizacion_draft_v1';
  // ---- DATOS FIJOS DE LA EMPRESA ----
  final String direccionEmpresa =
      "C. 59k N°518 X 112 Y 114 Col. Bojorquez Cp. 97230";
  final String ciudadEmpresa = "Mérida";
  final String sitioWeb = "www.cafrimx.com";
  final String telefonoEmpresa = "999-192-123-2";
  final String emailEmpresa = "facturaciones@cafrimx.com";
  final String responsable = "Lic. Elizabeth Barroso";

  // ---- DATOS TEMPORALES Y CONTROLADORES ----
  String? folioActual;
  String fecha = DateTime.now().toString().substring(0, 10);
  String clienteId = "";
  DateTime? _validoHastaDate;
  final TextEditingController _validoHastaController = TextEditingController();
  final TextEditingController _clienteBusquedaController =
      TextEditingController();

  Cliente? cliente;
  String? _clienteError;

  List<CotizacionItem> items = [];

  double get subtotal => items.fold(0, (acc, item) => acc + item.subtotal);
  double get totalImpuestos =>
      items.fold(0, (acc, item) => acc + (item.subtotal * item.impuesto));
  double get total => subtotal + totalImpuestos;

  @override
  void initState() {
    super.initState();
    _resetForm();
    _restoreDraft();
  }

  void _resetForm() {
    setState(() {
      folioActual = null;
      fecha = DateTime.now().toString().substring(0, 10);
      clienteId = "";
      _validoHastaDate = DateTime.now().add(const Duration(days: 7));
      _validoHastaController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(_validoHastaDate!);
      cliente = null;
      _clienteError = null;
      items = [];
      _clienteBusquedaController.clear();
    });
  }

  // ====== Persistencia local simple del borrador ======
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'fecha': fecha,
        'validoHasta': _validoHastaController.text,
        'cliente': cliente == null
            ? null
            : {
                'id': cliente!.id,
                'codigo': cliente!.codigo,
                'nombre': cliente!.nombre,
                'email': cliente!.email,
                'direccion': cliente!.direccion,
                'ciudad': cliente!.ciudad,
                'telefono': cliente!.telefono,
              },
        'items': items
            .map(
              (e) => {
                'codigo': e.codigo,
                'descripcion': e.descripcion,
                'cantidad': e.cantidad,
                'precio': e.precio,
                'impuesto': e.impuesto,
              },
            )
            .toList(),
      };
      // encode manual minimalista para evitar dependencias extra
      final json = StringBuffer('{');
      json.write('"fecha":"$fecha"');
      json.write(',"validoHasta":"${_validoHastaController.text}"');
      if (data['cliente'] != null) {
        final c = data['cliente'] as Map<String, dynamic>;
        json.write(',"cliente":{');
        json.write('"id":"${c['id']}"');
        json.write(',"codigo":"${c['codigo']}"');
        json.write(',"nombre":"${c['nombre']}"');
        json.write(',"email":"${c['email']}"');
        json.write(',"direccion":"${c['direccion']}"');
        json.write(',"ciudad":"${c['ciudad']}"');
        json.write(',"telefono":"${c['telefono']}"');
        json.write('}');
      }
      // items
      json.write(',"items":[');
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        json.write('{');
        json.write('"codigo":"${it.codigo}"');
        json.write(',"descripcion":"${it.descripcion.replaceAll('"', '\\"')}"');
        json.write(',"cantidad":${it.cantidad}');
        json.write(',"precio":${it.precio}');
        json.write(',"impuesto":${it.impuesto}');
        json.write('}');
        if (i < items.length - 1) json.write(',');
      }
      json.write(']');
      json.write('}');
      await prefs.setString(_draftKey, json.toString());
    } catch (_) {
      // ignora errores de persistencia
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return;
      // parseo muy básico
      // Para robustez podríamos usar dart:convert, pero evitamos dependencias adicionales.
      // Aquí, extraemos mediante expresiones regulares simples.
      String? extractString(String key) {
        final reg = RegExp('"$key":"(.*?)"');
        final m = reg.firstMatch(raw);
        return m?.group(1);
      }

      setState(() {
        fecha = extractString('fecha') ?? fecha;
        final valido = extractString('validoHasta');
        if (valido != null) {
          _validoHastaController.text = valido;
          try {
            _validoHastaDate = DateTime.parse(valido);
          } catch (_) {}
        }
      });

      // cliente
      if (raw.contains('"cliente":{')) {
        String sub = raw.split('"cliente":{').last;
        sub = sub.split('}')[0];
        String? cs(String k) {
          final reg = RegExp('"$k":"(.*?)"');
          final m = reg.firstMatch(sub);
          return m?.group(1);
        }

        final c = Cliente(
          id: cs('id') ?? '',
          codigo: cs('codigo') ?? '',
          nombre: cs('nombre') ?? '',
          email: cs('email') ?? '',
          direccion: cs('direccion') ?? '',
          ciudad: cs('ciudad') ?? '',
          telefono: cs('telefono') ?? '',
        );
        setState(() {
          cliente = c.id.isEmpty && c.nombre.isEmpty ? null : c;
          if (cliente != null) {
            _clienteBusquedaController.text =
                '${cliente!.nombre} (${cliente!.codigo})';
          }
        });
      }

      // items
      if (raw.contains('"items":[')) {
        String listPart = raw.split('"items":[').last;
        listPart = listPart.split(']')[0];
        final parts = listPart.isEmpty ? <String>[] : listPart.split('},{');
        final restored = <CotizacionItem>[];
        for (var p in parts) {
          String seg = p;
          if (!seg.startsWith('{')) seg = '{$seg';
          if (!seg.endsWith('}')) seg = '$seg}';
          String? ss(String k) {
            final r = RegExp('"$k":"(.*?)"');
            final m = r.firstMatch(seg);
            return m?.group(1);
          }

          String? sn(String k) {
            final r = RegExp('"$k":(-?[0-9.]+)');
            final m = r.firstMatch(seg);
            return m?.group(1);
          }

          final codigo = ss('codigo') ?? '';
          final descripcion = (ss('descripcion') ?? '').replaceAll('\\"', '"');
          final cantidad = int.tryParse(sn('cantidad') ?? '') ?? 1;
          final precio = double.tryParse(sn('precio') ?? '') ?? 0.0;
          final impuesto = double.tryParse(sn('impuesto') ?? '') ?? 0.16;
          restored.add(
            CotizacionItem(
              codigo: codigo,
              descripcion: descripcion,
              cantidad: cantidad,
              precio: precio,
              impuesto: impuesto,
            ),
          );
        }
        setState(() {
          items = restored;
        });
      }
    } catch (_) {
      // ignorar errores de restauración
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  /// Busca clientes por nombre o código que EMPIECEN con el patrón, hasta 10 resultados, evitando duplicados
  Future<List<Cliente>> _buscarSugerenciasCliente(String pattern) async {
    pattern = pattern.trim();
    if (pattern.isEmpty) return [];

    final nombreQuery = FirebaseFirestore.instance
        .collection('clientes')
        .where('nombre', isGreaterThanOrEqualTo: pattern)
        .where('nombre', isLessThanOrEqualTo: '$pattern\uf8ff')
        .limit(5)
        .get();

    final codigoQuery = FirebaseFirestore.instance
        .collection('clientes')
        .where('codigo', isGreaterThanOrEqualTo: pattern)
        .where('codigo', isLessThanOrEqualTo: '$pattern\uf8ff')
        .limit(5)
        .get();

    final correoQuery = FirebaseFirestore.instance
        .collection('clientes')
        .where('correo', isGreaterThanOrEqualTo: pattern)
        .where('correo', isLessThanOrEqualTo: '$pattern\uf8ff')
        .limit(5)
        .get();

    final results = await Future.wait([nombreQuery, codigoQuery, correoQuery]);
    final vistos = <String>{};
    return results
        .expand((q) => q.docs)
        .where((doc) => vistos.add(doc.id))
        .map((doc) => Cliente.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Autocomplete para servicios por código o concepto
  Future<List<Map<String, dynamic>>> _buscarSugerenciasServicio(
    String pattern,
  ) async {
    pattern = pattern.trim();
    if (pattern.isEmpty) return [];
    final byCodigo = await FirebaseFirestore.instance
        .collection('servicios')
        .where('codigo', isGreaterThanOrEqualTo: pattern)
        .where('codigo', isLessThanOrEqualTo: '$pattern\uf8ff')
        .limit(10)
        .get();
    final byConcepto = await FirebaseFirestore.instance
        .collection('servicios')
        .where('concepto', isGreaterThanOrEqualTo: pattern)
        .where('concepto', isLessThanOrEqualTo: '$pattern\uf8ff')
        .limit(10)
        .get();
    final vistos = <String>{};
    final resultados = [
      ...byCodigo.docs,
      ...byConcepto.docs,
    ].where((doc) => vistos.add(doc.id)).map((doc) => doc.data()).toList();
    return resultados;
  }

  /// Diálogo para agregar o editar productos/servicios, ahora con Autocomplete
  Future<void> _mostrarAgregarServicioDialog({
    CotizacionItem? editarItem,
    int? editarIndex,
  }) async {
    final codigoController = TextEditingController(
      text: editarItem?.codigo ?? '',
    );
    final cantidadController = TextEditingController(
      text: editarItem?.cantidad.toString() ?? '1',
    );
    final precioController = TextEditingController(
      text: editarItem?.precio.toStringAsFixed(2) ?? '',
    );
    String? error;
    bool buscando = false;
    Map<String, dynamic>? servicioData;
    double impuestoSeleccionado = editarItem?.impuesto ?? 0.16;

    if (editarItem != null) {
      servicioData = {
        'codigo': editarItem.codigo,
        'concepto': editarItem.descripcion,
        'precioMenudeo': editarItem.precio,
      };
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> buscarServicio() async {
              setStateDialog(() {
                buscando = true;
                error = null;
                servicioData = null;
              });
              try {
                final query = await FirebaseFirestore.instance
                    .collection('servicios')
                    .where('codigo', isEqualTo: codigoController.text.trim())
                    .limit(1)
                    .get();
                if (query.docs.isNotEmpty) {
                  servicioData = query.docs.first.data();
                  if (editarItem == null) {
                    precioController.text =
                        (servicioData!['precioMenudeo'] as num?)
                            ?.toStringAsFixed(2) ??
                        '';
                  }
                } else {
                  error = "Servicio no encontrado";
                }
              } catch (e) {
                error = "Error: $e";
              }
              setStateDialog(() {
                buscando = false;
              });
            }

            return AlertDialog(
              title: Text(
                editarItem == null
                    ? 'Agregar producto/servicio'
                    : 'Editar producto/servicio',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // === AUTOCOMPLETE INTEGRADO para código de servicio ===
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.trim().isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      try {
                        return await _buscarSugerenciasServicio(
                          textEditingValue.text,
                        );
                      } catch (_) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                    },
                    displayStringForOption: (data) =>
                        '${data['codigo'] ?? ''} - ${data['concepto'] ?? ''}',
                    onSelected: (data) {
                      codigoController.text = data['codigo'] ?? '';
                      precioController.text =
                          (data['precioMenudeo'] as num?)?.toStringAsFixed(2) ??
                          '';
                      setStateDialog(() {
                        servicioData = data;
                        error = null;
                      });
                    },
                    fieldViewBuilder:
                        (context, ctrl, focusNode, onFieldSubmitted) {
                          if (editarItem == null) {
                            codigoController.value = ctrl.value;
                            return TextField(
                              controller: ctrl,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Código o nombre de servicio',
                              ),
                              onEditingComplete: onFieldSubmitted,
                            );
                          } else {
                            return TextField(
                              controller: codigoController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Código de servicio',
                              ),
                              readOnly: true,
                            );
                          }
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Material(
                        elevation: 4,
                        child: ListView.builder(
                          itemCount: options.length,
                          itemBuilder: (ctx, idx) {
                            final data = options.elementAt(idx);
                            return ListTile(
                              title: Text('${data['codigo'] ?? ''}'),
                              subtitle: Text('${data['concepto'] ?? ''}'),
                              onTap: () => onSelected(data),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (editarItem == null)
                    ElevatedButton(
                      onPressed: buscando ? null : buscarServicio,
                      child: buscando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Buscar'),
                    ),
                  if (servicioData != null) ...[
                    const SizedBox(height: 12),
                    Text('Concepto: ${servicioData!['concepto'] ?? ''}'),
                    TextField(
                      controller: precioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio (puede editarlo)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cantidadController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<double>(
                      initialValue: impuestoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Impuesto',
                        border: OutlineInputBorder(),
                      ),
                      items: [                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
                        DropdownMenuItem(value: -0.16, child: Text('-16%')),
                        DropdownMenuItem(value: 0.0, child: Text('0%')),
                        DropdownMenuItem(value: 0.16, child: Text('+16%')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            impuestoSeleccionado = value;
                          });
                        }
                      },
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                if (servicioData != null)
                  ElevatedButton(
                    onPressed: () {
                      final cantidad =
                          int.tryParse(cantidadController.text) ?? 1;
                      final precioFinal =
                          double.tryParse(
                            precioController.text.replaceAll(',', '.'),
                          ) ??
                          0.0;
                      final conceptoFinal = servicioData!['concepto'] ?? '';
                      final codigoFinal = servicioData!['codigo'] ?? '';
                      final nuevoItem = CotizacionItem(
                        codigo: codigoFinal,
                        descripcion: conceptoFinal,
                        cantidad: cantidad,
                        precio: precioFinal,
                        impuesto: impuestoSeleccionado,
                      );
                      setState(() {
                        if (editarItem != null && editarIndex != null) {
                          items[editarIndex] = nuevoItem;
                        } else {
                          items.add(nuevoItem);
                        }
                      });
                      _saveDraft();
                      Navigator.pop(context);
                    },
                    child: Text(editarItem == null ? 'Agregar' : 'Guardar'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _eliminarItem(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto/servicio'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este producto/servicio de la cotización?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        items.removeAt(index);
      });
      _saveDraft();
    }
  }

  String generarFolio() {
    final now = DateTime.now();
    return 'RC-${DateFormat('yyyyMMdd-HHmmss').format(now)}';
  }

  Future<String?> _guardarCotizacionEnFirebase() async {
    if (cliente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona un cliente')),
      );
      return null;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto/servicio')),
      );
      return null;
    }
    final folio = generarFolio();
    try {
      await FirebaseFirestore.instance.collection('cotizaciones').add({
        'folio': folio,
        'fecha': fecha,
        'validoHasta': _validoHastaController.text,
        'clienteId': cliente?.id,
        'cliente': {
          'codigo': cliente?.codigo,
          'nombre': cliente?.nombre,
          'email': cliente?.email,
          'direccion': cliente?.direccion,
          'ciudad': cliente?.ciudad,
          'telefono': cliente?.telefono,
        },
        'items': items
            .map(
              (item) => {
                'codigo': item.codigo,
                'descripcion': item.descripcion,
                'cantidad': item.cantidad,
                'precio': item.precio,
                'impuesto': item.impuesto,
                'subtotal': item.subtotal,
                'total': item.total,
              },
            )
            .toList(),
        'subtotal': subtotal,
        'totalImpuestos': totalImpuestos,
        'total': total,
        'empresa': {
          'direccion': direccionEmpresa,
          'ciudad': ciudadEmpresa,
          'sitioWeb': sitioWeb,
          'telefono': telefonoEmpresa,
          'email': emailEmpresa,
          'responsable': responsable,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        folioActual = folio;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cotización guardada con folio $folio')),
      );
      return folio;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      return null;
    }
  }

  Future<void> _exportarAPDF() async {
    final folio = await _guardarCotizacionEnFirebase();
    if (folio == null) return;

    final pdf = pw.Document();

    final logoBytes = await DefaultAssetBundle.of(
      context,
    ).load('lib/assets/cafrilogo.png');
    final firmaBytes = await DefaultAssetBundle.of(
      context,
    ).load('lib/assets/firma.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final firmaImage = pw.MemoryImage(firmaBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        // Margen amplio: 30 pt = ~1cm. Puedes aumentar si necesitas más espacio blanco.
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        build: (pw.Context context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 80, height: 80, child: pw.Image(logoImage)),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(direccionEmpresa),
                    pw.Text("Ciudad: $ciudadEmpresa"),
                    pw.Text("Sitio web: $sitioWeb"),
                    pw.Text("Teléfono: $telefonoEmpresa"),
                    pw.Text("E-mail: $emailEmpresa"),
                    pw.Text("Responsable: $responsable"),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Fecha: $fecha"),
                  pw.Text("Folio: $folio"),
                  pw.Text("Cliente ID: ${cliente?.id ?? ''}"),
                  pw.Text("Válido hasta: ${_validoHastaController.text}"),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.Text(
            "Cliente",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (cliente != null) ...[
            pw.Text("Código: ${cliente!.codigo}"),
            pw.Text("Nombre: ${cliente!.nombre}"),
            pw.Text("Email: ${cliente!.email}"),
            pw.Text("Dirección: ${cliente!.direccion}"),
            pw.Text("Ciudad: ${cliente!.ciudad}"),
            pw.Text("Teléfono: ${cliente!.telefono}"),
          ],
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.Text(
            "Productos/Servicios",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          // --- TABLA AMPLIA Y LEGIBLE ---
          pw.TableHelper.fromTextArray(
            headers: [
              'Código',
              'Descripción',
              'Cantidad',
              'Precio',
              'Subtotal',
              'Impuesto',
              'Total',
            ],
            data: items
                .map(
                  (item) => [
                    item.codigo,
                    item.descripcion,
                    item.cantidad.toString(),
                    '\$${item.precio.toStringAsFixed(2)}',
                    '\$${item.subtotal.toStringAsFixed(2)}',
                    '\$${(item.subtotal * item.impuesto).toStringAsFixed(2)}',
                    '\$${item.total.toStringAsFixed(2)}',
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(
              fontSize: 8,
            ), // 👈 Fuente chica (compacto)
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            cellAlignment: pw.Alignment.center,
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
            cellPadding: const pw.EdgeInsets.symmetric(
              vertical: 2,
              horizontal: 2,
            ), // 👈 Padding mínimo
            columnWidths: {
              0: const pw.FlexColumnWidth(1), // Código
              1: const pw.FlexColumnWidth(
                2.4,
              ), // Descripción (amplia pero ajustada)
              2: const pw.FlexColumnWidth(0.7), // Cantidad
              3: const pw.FlexColumnWidth(1.0), // Precio
              4: const pw.FlexColumnWidth(1.0), // Subtotal
              5: const pw.FlexColumnWidth(1.0), // Impuesto
              6: const pw.FlexColumnWidth(1.1), // Total
            },
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Subtotal: \$${subtotal.toStringAsFixed(2)}'),
                  pw.Text('Impuestos: \$${totalImpuestos.toStringAsFixed(2)}'),
                  pw.Text(
                    'Total: \$${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Términos y condiciones',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('1.- Todo costo del servicio incluye IVA.'),
                    pw.Text('2.- Los pagos son por medio de transferencia.'),
                    pw.Text(
                      '3.- Todo servicio es realizado con el 50% de anticipo del servicio.',
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 120,
                      height: 40,
                      child: pw.Image(firmaImage),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'FIRMA DE ENCARGADA',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Si usted tiene alguna pregunta sobre esta cotización, por favor, póngase en contacto con nosotros',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'CAFRI | Teléfono: 99-91-02-12-32 | E-mail: facturaciones@cafrimx.com',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'En Frio y Confort "CAFRI es la Solución"',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cotización")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------ ENCABEZADO EMPRESA/CLIENTE/FOLIO -----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'lib/assets/cafrilogo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(direccionEmpresa),
                      Text("Ciudad: $ciudadEmpresa"),
                      Text("Sitio web: $sitioWeb"),
                      Text("Teléfono: $telefonoEmpresa"),
                      Text("E-mail: $emailEmpresa"),
                      Text("Responsable: $responsable"),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Fecha: $fecha"),
                    Text("Folio: ${folioActual ?? 'Sin generar'}"),
                    Text("Cliente ID: ${cliente?.id ?? ''}"),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _validoHastaController,
                        readOnly: false,
                        decoration: const InputDecoration(
                          labelText: "Válido hasta",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          FocusScope.of(context).requestFocus(FocusNode());
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _validoHastaDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _validoHastaDate = picked;
                              _validoHastaController.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                            });
                            _saveDraft();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Center(
              child: Text(
                "Cliente",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            // 🔥 AUTOCOMPLETE INTEGRATION 🔥
            Autocomplete<Cliente>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.trim().isEmpty) {
                  return const Iterable<Cliente>.empty();
                }
                try {
                  return await _buscarSugerenciasCliente(textEditingValue.text);
                } catch (_) {
                  return const Iterable<Cliente>.empty();
                }
              },
              displayStringForOption: (Cliente c) =>
                  '${c.nombre} (${c.codigo})',
              optionsViewBuilder: (context, onSelected, options) {
                return Material(
                  elevation: 4,
                  child: ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (ctx, idx) {
                      final c = options.elementAt(idx);
                      return ListTile(
                        title: Text('${c.nombre} (${c.codigo})'),
                        subtitle: Text('${c.email} · ${c.ciudad}'),
                        trailing: Text(c.telefono),
                        onTap: () => onSelected(c),
                      );
                    },
                  ),
                );
              },
              onSelected: (Cliente c) {
                setState(() {
                  cliente = c;
                  _clienteBusquedaController.text = '${c.nombre} (${c.codigo})';
                  _clienteError = null;
                });
                _saveDraft();
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    _clienteBusquedaController.value = controller.value;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: "Busca cliente por nombre, código o correo",
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      autofocus: false,
                    );
                  },
            ),
            if (_clienteError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _clienteError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (cliente != null) ...[
              const SizedBox(height: 8),
              Text("Código: ${cliente!.codigo}"),
              Text("Nombre: ${cliente!.nombre}"),
              Text("Email: ${cliente!.email}"),
              Text("Dirección: ${cliente!.direccion}"),
              Text("Ciudad: ${cliente!.ciudad}"),
              Text("Teléfono: ${cliente!.telefono}"),
            ],
            const Divider(height: 32),
            // ----------- PRODUCTOS/SERVICIOS DE COTIZACIÓN -----------
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Código')),
                  DataColumn(label: Text('Descripción')),
                  DataColumn(label: Text('Cantidad')),
                  DataColumn(label: Text('Precio')),
                  DataColumn(label: Text('Subtotal')),
                  DataColumn(label: Text('Impuesto')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: List.generate(items.length, (index) {
                  final item = items[index];
                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      return index.isEven
                          ? Colors.white
                          : const Color(0xFFE3F2FD);
                    }),
                    cells: [
                      DataCell(Text(item.codigo)),
                      DataCell(
                        SizedBox(
                          width: 350,
                          child: Text(
                            item.descripcion,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      DataCell(Text('${item.cantidad}')),
                      DataCell(Text('\$${item.precio.toStringAsFixed(2)}')),
                      DataCell(Text('\$${item.subtotal.toStringAsFixed(2)}')),
                      DataCell(
                        Text(
                          '\$${(item.subtotal * item.impuesto).toStringAsFixed(2)}',
                        ),
                      ),
                      DataCell(Text('\$${item.total.toStringAsFixed(2)}')),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Editar',
                              onPressed: () {
                                _mostrarAgregarServicioDialog(
                                  editarItem: item,
                                  editarIndex: index,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Eliminar',
                              onPressed: () => _eliminarItem(index),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _mostrarAgregarServicioDialog(),
              child: const Text("Agregar producto/servicio"),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.only(right: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Términos y condiciones',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('1.- Todo costo del servicio incluye IVA.'),
                        Text('2.- Los pagos son por medio de transferencia.'),
                        Text(
                          '3.- Todo servicio es realizado con el 50% de anticipo del servicio.',
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal: \$${subtotal.toStringAsFixed(2)}'),
                        Text(
                          'Impuestos: \$${totalImpuestos.toStringAsFixed(2)}',
                        ),
                        Text(
                          'Total: \$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Image.asset(
                          'lib/assets/firma.png',
                          width: 160,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'FIRMA DE ENCARGADA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: const [
                  Text(
                    'Si usted tiene alguna pregunta sobre esta cotización, por favor, póngase en contacto con nosotros',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'CAFRI | Teléfono: 99-91-02-12-32 | E-mail: facturaciones@cafrimx.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'En Frio y Confort "CAFRI es la\nSolución"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _exportarAPDF();
                  await _clearDraft();
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Exportar a PDF y guardar"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Opción B) Volver a GENERAR el PDF (a partir de los datos)
// Dado que NO guardas el archivo PDF, sino solo los datos:
// Para descargar el PDF después, necesitas abrir tu pantalla/código de generación y “re-crear” el PDF usando los datos de esa cotización, tal como lo hiciste la primera vez.

// ¿Cómo?

// Haz un listado de cotizaciones guardadas (DataTable/ListView de Firestore).
// Al seleccionar una cotización:
// Recupera sus datos.
// Usa tu mismo código de generación de PDF con esos datos.
// Llama a Printing.layoutPdf(...).
// El usuario podrá descargar/imprimir el PDF de nuevo.
// No vuelve a aparecer a menos que lo generes nuevamente con el mismo método.
