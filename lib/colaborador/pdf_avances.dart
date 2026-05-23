// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cafri/helpers/local_pdf_storage.dart';
import 'package:cafri/helpers/upload_pdf_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'folio_service.dart';

class MaterialRowData {
  final TextEditingController material = TextEditingController();
  final TextEditingController unidad = TextEditingController();
  final TextEditingController cantidad = TextEditingController();
  final TextEditingController observaciones = TextEditingController();

  void dispose() {
    material.dispose();
    unidad.dispose();
    cantidad.dispose();
    observaciones.dispose();
  }

  Map<String, String> toMap() => {
        'material': material.text,
        'unidad': unidad.text,
        'cantidad': cantidad.text,
        'observaciones': observaciones.text,
      };
}

class FormularioAvancesPDF extends StatefulWidget {
  const FormularioAvancesPDF({super.key});

  @override
  State<FormularioAvancesPDF> createState() => _FormularioAvancesPDFState();
}

class _FormularioAvancesPDFState extends State<FormularioAvancesPDF>
    with WidgetsBindingObserver {
  // Paleta de colores visuales
  static const _colorBg = Color(0xFFF3F6FB);
  static const _colorCard = Colors.white;
  static const _colorHeader = Color(0xFF003366);
  static const _colorAccent = Color(0xFF0056B3);

  // Datos generales
  final TextEditingController proyectoObra = TextEditingController();
  final TextEditingController clienteContratista = TextEditingController();
  
  // Sección Obra
  final TextEditingController obraDescripcion = TextEditingController();
  final TextEditingController obraEspecificaciones = TextEditingController();

  // Avances (fotos)
  final List<Uint8List> fotosInicio = [];
  final List<Uint8List> fotosDurante = [];
  final List<Uint8List> fotosDespues = [];

  // Reporte del día
  final TextEditingController actividadRealizada = TextEditingController();
  final TextEditingController areaNivelObra = TextEditingController();

  // Resumen de materiales (tabla)
  final List<MaterialRowData> materiales = [MaterialRowData()];

  // Descripción del trabajo
  final TextEditingController descripcionTrabajo = TextEditingController();

  // Firmas
  final SignatureController firmaTecnicoController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final SignatureController firmaClienteController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  Uint8List? firmaTecnico;
  Uint8List? firmaCliente;
  final TextEditingController nombreTecnicoController = TextEditingController();
  final TextEditingController nombreClienteController = TextEditingController();

  // Folio
  int? folioActual;
  bool cargandoFolio = true;

  static const String _draftKey = 'pdf_avances_draft_v1';
  static const int _maxFotosPorSeccion = 12;
  static const int _jpegQuality = 75;

  final Set<TextEditingController> _autosaveControllers = {};
  Timer? _autosaveTimer;
  bool _isRestoringDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchAllControllers();
    _cargarFolio();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRestoreDraft();
    });
  }

  Future<void> _cargarFolio() async {
    final f = await FolioService.getNextFolio();
    setState(() {
      folioActual = f;
      cargandoFolio = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    proyectoObra.dispose();
    clienteContratista.dispose();
    obraDescripcion.dispose();
    obraEspecificaciones.dispose();
    actividadRealizada.dispose();
    areaNivelObra.dispose();
    descripcionTrabajo.dispose();
    firmaTecnicoController.dispose();
    firmaClienteController.dispose();
    nombreTecnicoController.dispose();
    nombreClienteController.dispose();
    for (final m in materiales) {
      m.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDraft();
    }
  }

  void _watchController(TextEditingController controller) {
    if (_autosaveControllers.add(controller)) {
      controller.addListener(_scheduleAutosave);
    }
  }

  void _watchMaterialRow(MaterialRowData row) {
    _watchController(row.material);
    _watchController(row.unidad);
    _watchController(row.cantidad);
    _watchController(row.observaciones);
  }

  void _watchAllControllers() {
    _watchController(proyectoObra);
    _watchController(clienteContratista);
    _watchController(obraDescripcion);
    _watchController(obraEspecificaciones);
    _watchController(actividadRealizada);
    _watchController(areaNivelObra);
    _watchController(descripcionTrabajo);
    _watchController(nombreTecnicoController);
    _watchController(nombreClienteController);
    for (final row in materiales) {
      _watchMaterialRow(row);
    }
  }

  void _scheduleAutosave() {
    if (_isRestoringDraft) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      _saveDraft();
    });
  }

  Map<String, dynamic> _buildDraftMap() => {
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'folioActual': folioActual,
        'proyectoObra': proyectoObra.text,
        'clienteContratista': clienteContratista.text,
        'obraDescripcion': obraDescripcion.text,
        'obraEspecificaciones': obraEspecificaciones.text,
        'actividadRealizada': actividadRealizada.text,
        'areaNivelObra': areaNivelObra.text,
        'descripcionTrabajo': descripcionTrabajo.text,
        'nombreTecnico': nombreTecnicoController.text,
        'nombreCliente': nombreClienteController.text,
        'materiales': materiales.map((m) => m.toMap()).toList(),
      };

  bool _isFormBasicallyEmpty() {
    if (proyectoObra.text.trim().isNotEmpty) return false;
    if (clienteContratista.text.trim().isNotEmpty) return false;
    if (obraDescripcion.text.trim().isNotEmpty) return false;
    if (obraEspecificaciones.text.trim().isNotEmpty) return false;
    if (actividadRealizada.text.trim().isNotEmpty) return false;
    if (areaNivelObra.text.trim().isNotEmpty) return false;
    if (descripcionTrabajo.text.trim().isNotEmpty) return false;
    if (nombreTecnicoController.text.trim().isNotEmpty) return false;
    if (nombreClienteController.text.trim().isNotEmpty) return false;
    if (fotosInicio.isNotEmpty || fotosDurante.isNotEmpty || fotosDespues.isNotEmpty) {
      return false;
    }
    if (firmaTecnico != null || firmaCliente != null) return false;
    return !materiales.any((m) =>
        m.material.text.trim().isNotEmpty ||
        m.unidad.text.trim().isNotEmpty ||
        m.cantidad.text.trim().isNotEmpty ||
        m.observaciones.text.trim().isNotEmpty);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode(_buildDraftMap()));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _applyDraft(Map<String, dynamic> draft) async {
    _isRestoringDraft = true;
    try {
      proyectoObra.text = (draft['proyectoObra'] ?? '').toString();
      clienteContratista.text = (draft['clienteContratista'] ?? '').toString();
      obraDescripcion.text = (draft['obraDescripcion'] ?? '').toString();
      obraEspecificaciones.text = (draft['obraEspecificaciones'] ?? '').toString();
      actividadRealizada.text = (draft['actividadRealizada'] ?? '').toString();
      areaNivelObra.text = (draft['areaNivelObra'] ?? '').toString();
      descripcionTrabajo.text = (draft['descripcionTrabajo'] ?? '').toString();
      nombreTecnicoController.text = (draft['nombreTecnico'] ?? '').toString();
      nombreClienteController.text = (draft['nombreCliente'] ?? '').toString();

      for (final row in materiales) {
        row.dispose();
      }
      materiales.clear();

      final materialesDraft = draft['materiales'] is List ? draft['materiales'] as List : <dynamic>[];
      if (materialesDraft.isEmpty) {
        final row = MaterialRowData();
        materiales.add(row);
        _watchMaterialRow(row);
      } else {
        for (final item in materialesDraft) {
          final row = MaterialRowData();
          materiales.add(row);
          _watchMaterialRow(row);
          if (item is Map) {
            final map = item.cast<String, dynamic>();
            row.material.text = (map['material'] ?? '').toString();
            row.unidad.text = (map['unidad'] ?? '').toString();
            row.cantidad.text = (map['cantidad'] ?? '').toString();
            row.observaciones.text = (map['observaciones'] ?? '').toString();
          }
        }
      }
    } finally {
      _isRestoringDraft = false;
    }

    if (mounted) setState(() {});
  }

  Future<void> _maybeRestoreDraft() async {
    final draft = await _readDraft();
    if (draft == null || !mounted) return;

    if (_isFormBasicallyEmpty()) {
      await _applyDraft(draft);
      return;
    }

    final savedAt = (draft['savedAt'] ?? '').toString();
    final restore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrador detectado'),
        content: Text(
          savedAt.isNotEmpty
              ? 'Hay un borrador de avances guardado ($savedAt). ¿Deseas restaurarlo?'
              : 'Hay un borrador de avances guardado. ¿Deseas restaurarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _clearDraft();
            },
            child: const Text('Descartar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (restore == true) {
      await _applyDraft(draft);
    }
  }

  void _limpiarFormulario() {
    proyectoObra.clear();
    clienteContratista.clear();
    obraDescripcion.clear();
    obraEspecificaciones.clear();
    fotosInicio.clear();
    fotosDurante.clear();
    fotosDespues.clear();
    actividadRealizada.clear();
    areaNivelObra.clear();
    descripcionTrabajo.clear();
    firmaTecnico = null;
    firmaCliente = null;
    firmaTecnicoController.clear();
    firmaClienteController.clear();
    nombreTecnicoController.clear();
    nombreClienteController.clear();

    for (final row in materiales) {
      row.dispose();
    }
    materiales
      ..clear()
      ..add(MaterialRowData());
    _watchMaterialRow(materiales.first);
    _clearDraft();
  }

  static Uint8List _downscaleJpeg(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final maxSide = decoded.width > decoded.height ? decoded.width : decoded.height;
      if (maxSide <= 1280) {
        return Uint8List.fromList(
          img.encodeJpg(decoded, quality: _jpegQuality),
        );
      }
      final ratio = 1280 / maxSide;
      final newWidth = (decoded.width * ratio).round();
      final newHeight = (decoded.height * ratio).round();
      final resized = img.copyResize(
        decoded,
        width: newWidth,
        height: newHeight,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
    } catch (_) {
      return bytes;
    }
  }

  String? _validar() {
    if (proyectoObra.text.trim().isEmpty) return 'Proyecto/Obra es obligatorio';
    if (clienteContratista.text.trim().isEmpty) return 'Cliente/Contratista es obligatorio';
    if (actividadRealizada.text.trim().isEmpty) return 'Actividad realizada es obligatorio';
    if (areaNivelObra.text.trim().isEmpty) return 'Área/Nivel de obra es obligatorio';
    if (firmaTecnico == null || nombreTecnicoController.text.trim().isEmpty) {
      return 'Falta firma o nombre del técnico';
    }
    if (firmaCliente == null || nombreClienteController.text.trim().isEmpty) {
      return 'Falta firma o nombre del cliente';
    }
    return null;
  }

  Future<void> _tomarFirmas({required bool esTecnico}) async {
    final controller = esTecnico ? firmaTecnicoController : firmaClienteController;
    final nombreController = esTecnico ? nombreTecnicoController : nombreClienteController;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(
                esTecnico ? 'Firma del técnico' : 'Firma del cliente',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _colorHeader),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Signature(
                          controller: controller,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    controller.clear();
                    setDialogState(() {});
                  },
                  child: const Text('Limpiar', style: TextStyle(color: Colors.orange)),
                ),
                TextButton(
                  onPressed: () async {
                    if (controller.isNotEmpty && nombreController.text.trim().isNotEmpty) {
                      final png = await controller.toPngBytes();
                      Navigator.of(context).pop({'firma': png, 'nombre': nombreController.text.trim()});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La firma y el nombre son obligatorios.')),
                      );
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: _colorAccent, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (esTecnico) {
          firmaTecnico = result['firma'];
        } else {
          firmaCliente = result['firma'];
        }
      });
      _scheduleAutosave();
    }
  }

  Future<void> _agregarFotos(List<Uint8List> destino) async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: _jpegQuality,
      );
      if (!mounted || pickedList.isEmpty) return;

      final cupo = _maxFotosPorSeccion - destino.length;
      if (cupo <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Límite: $_maxFotosPorSeccion fotos en esta sección.')),
        );
        return;
      }

      final bytesList = <Uint8List>[];
      for (final xfile in pickedList.take(cupo)) {
        final bytes = await xfile.readAsBytes();
        bytesList.add(_downscaleJpeg(bytes));
      }

      if (!mounted) return;
      setState(() => destino.addAll(bytesList));
      _scheduleAutosave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo agregar la(s) foto(s): $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _seccionConTitulo(String titulo, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: _colorHeader,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _encabezadoCafri() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              "lib/assets/cafrilogo.png",
              width: 70,
              height: 70,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 70,
                height: 70,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORTE DE AVANCES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: _colorHeader,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'COMPAÑÍA DE AIRE ACONDICIONADO Y FRIGORIFICOS DEL SURESTE S.A. DE C.V.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 6),
                _buildHeaderInfoRow(Icons.phone, '(999) 102 1232'),
                _buildHeaderInfoRow(Icons.badge, 'AAF2306305G0'),
                _buildHeaderInfoRow(Icons.email, 'contacto@cafrimx.com'),
                _buildHeaderInfoRow(Icons.location_on, 'C. 59K N°537 POR 112 Y 114 COL. BOJORQUEZ C.P 97230'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: _colorAccent),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
        ],
      ),
    );
  }

  Widget _fotosSeccion(String titulo, List<Uint8List> fotos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: _colorHeader, fontSize: 14)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: fotos.length + 1,
          itemBuilder: (context, idx) {
            if (idx == fotos.length) {
              return GestureDetector(
                onTap: () => _agregarFotos(fotos),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.add_a_photo, size: 24, color: _colorAccent),
                ),
              );
            }
            final imgBytes = fotos[idx];
            return Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(imgBytes, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => fotos.removeAt(idx));
                      _scheduleAutosave();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.cancel, color: Colors.red, size: 18),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      floatingLabelStyle: const TextStyle(color: _colorAccent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _colorAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaActual = DateTime.now();
    final fechaFormateada = '${fechaActual.day.toString().padLeft(2, '0')}/${fechaActual.month.toString().padLeft(2, '0')}/${fechaActual.year} ${fechaActual.hour.toString().padLeft(2, '0')}:${fechaActual.minute.toString().padLeft(2, '0')}';

    if (cargandoFolio || folioActual == null) {
      return const Scaffold(
        backgroundColor: _colorBg,
        body: Center(child: CircularProgressIndicator(color: _colorAccent)),
      );
    }

    return Scaffold(
      backgroundColor: _colorBg,
      appBar: AppBar(
        title: const Text('Reporte de Avances', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: _colorHeader,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _encabezadoCafri(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _colorCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Folio: ', style: TextStyle(fontWeight: FontWeight.bold, color: _colorHeader, fontSize: 14)),
                        Text('$folioActual', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Text('Fecha: $fechaFormateada', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              _seccionConTitulo(
                '1. Datos generales',
                Column(
                  children: [
                    TextField(controller: proyectoObra, decoration: _inputStyle('Proyecto/Obra')),
                    const SizedBox(height: 12),
                    TextField(controller: clienteContratista, decoration: _inputStyle('Cliente/Contratista')),
                  ],
                ),
              ),
              _seccionConTitulo(
                '2. Obra',
                Column(
                  children: [
                    TextField(controller: obraDescripcion, decoration: _inputStyle('Descripción de la obra'), maxLines: 3),
                    const SizedBox(height: 12),
                    TextField(controller: obraEspecificaciones, decoration: _inputStyle('Especificaciones técnicas'), maxLines: 3),
                  ],
                ),
              ),
              _seccionConTitulo(
                '3. Avances (fotos)',
                Column(
                  children: [
                    _fotosSeccion('Inicio', fotosInicio),
                    const Divider(height: 24),
                    _fotosSeccion('Durante', fotosDurante),
                    const Divider(height: 24),
                    _fotosSeccion('Después', fotosDespues),
                  ],
                ),
              ),
              _seccionConTitulo(
                '4. Reporte del día',
                Column(
                  children: [
                    TextField(controller: actividadRealizada, decoration: _inputStyle('Actividad realizada'), maxLines: 2),
                    const SizedBox(height: 12),
                    TextField(controller: areaNivelObra, decoration: _inputStyle('Área/Nivel de obra')),
                  ],
                ),
              ),
              _seccionConTitulo(
                '5. Resumen de materiales utilizados',
                Column(
                  children: [
                    ...materiales.asMap().entries.map((e) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: TextField(controller: e.value.material, decoration: _inputStyle('Material'))),
                                const SizedBox(width: 8),
                                SizedBox(width: 100, child: TextField(controller: e.value.unidad, decoration: _inputStyle('Unidad'))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: e.value.cantidad,
                                    decoration: _inputStyle('Cant.'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: e.value.observaciones, decoration: _inputStyle('Observaciones'))),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      if (materiales.length > 1) {
                                        final row = materiales.removeAt(e.key);
                                        row.dispose();
                                      }
                                    });
                                    _scheduleAutosave();
                                  },
                                )
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final row = MaterialRowData();
                          _watchMaterialRow(row);
                          setState(() => materiales.add(row));
                          _scheduleAutosave();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar material', style: TextStyle(fontSize: 13)),
                      ),
                    )
                  ],
                ),
              ),
              _seccionConTitulo(
                '6. Descripción del trabajo',
                TextField(controller: descripcionTrabajo, decoration: _inputStyle('Describe el trabajo realizado'), maxLines: 4),
              ),
              _seccionConTitulo(
                '7. Firmas',
                Row(
                  children: [
                    Expanded(child: _buildFirmaWidget(esTecnico: true, bytes: firmaTecnico, nombre: nombreTecnicoController.text)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFirmaWidget(esTecnico: false, bytes: firmaCliente, nombre: nombreClienteController.text)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorHeader,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('GUARDAR COMO PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                  onPressed: () async {
                    final validation = _validar();
                    if (validation != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation)));
                      return;
                    }

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar generación de PDF'),
                        content: const Text('¿Deseas generar y enviar el PDF?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, continuar')),
                        ],
                      ),
                    );
                    if (confirm != true) return;

                    if (!mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Dialog(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: _colorAccent),
                              SizedBox(height: 16),
                              Text('Generando y enviando PDF...'),
                            ],
                          ),
                        ),
                      ),
                    );

                    try {
                      final logoBytes = (await rootBundle.load('lib/assets/cafrilogo.png')).buffer.asUint8List();
                      final folioParaPDF = folioActual!;

                      final bytes = await PdfAvancesGenerator.generatePdf(
                        folio: folioParaPDF,
                        fechaFormateada: fechaFormateada,
                        proyectoObra: proyectoObra.text,
                        clienteContratista: clienteContratista.text,
                        obraDescripcion: obraDescripcion.text,
                        obraEspecificaciones: obraEspecificaciones.text,
                        fotosInicio: fotosInicio,
                        fotosDurante: fotosDurante,
                        fotosDespues: fotosDespues,
                        actividadRealizada: actividadRealizada.text,
                        areaNivelObra: areaNivelObra.text,
                        materiales: materiales.map((m) => m.toMap()).toList(),
                        descripcionTrabajo: descripcionTrabajo.text,
                        firmaTecnico: firmaTecnico!,
                        nombreTecnico: nombreTecnicoController.text.trim(),
                        firmaCliente: firmaCliente!,
                        nombreCliente: nombreClienteController.text.trim(),
                        logoBytes: logoBytes,
                      );

                      if (bytes.isEmpty) {
                        throw Exception('El PDF generado está vacío');
                      }

                      String? localPdfPath;
                      String? localPdfError;
                      try {
                        localPdfPath = await guardarCopiaPdfEnTelefono(
                          pdfBytes: bytes,
                          fileName: 'Avance_$folioParaPDF.pdf',
                        );
                      } catch (e) {
                        localPdfError = e.toString();
                      }

                      try {
                        await subirPdfAvances(
                          bytes,
                          folioParaPDF,
                          nombreCliente: clienteContratista.text,
                        );
                      } catch (e) {
                        final errorMsg = e.toString();
                        if (mounted) Navigator.of(context).pop();
                        
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(localPdfPath != null ? '$errorMsg\nCopia local: $localPdfPath' : '$errorMsg\nNo se pudo guardar copia local: $localPdfError'),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                        return;
                      }

                      await FolioService.updateFolio(folioParaPDF);
                      
                      if (mounted) Navigator.of(context).pop();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localPdfPath != null ? '✓ PDF enviado exitosamente\nFolio: $folioParaPDF\nCopia local: $localPdfPath' : '✓ PDF enviado exitosamente\nFolio: $folioParaPDF'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 5),
                        ),
                      );

                      setState(() {
                        folioActual = folioParaPDF + 1;
                        _limpiarFormulario();
                      });

                      await Printing.layoutPdf(
                        onLayout: (format) async => bytes,
                        name: 'Avance($folioParaPDF).pdf',
                      );
                    } catch (e) {
                      if (mounted) Navigator.of(context).pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirmaWidget({required bool esTecnico, required Uint8List? bytes, required String nombre}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            esTecnico ? 'Técnico' : 'Cliente',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _colorHeader, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (bytes != null) ...[
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            Text(nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            TextButton(
              onPressed: () {
                setState(() {
                  if (esTecnico) {
                    firmaTecnico = null;
                  } else {
                    firmaCliente = null;
                  }
                });
                _scheduleAutosave();
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontSize: 12)),
            )
          ] else
            OutlinedButton.icon(
              onPressed: () => _tomarFirmas(esTecnico: esTecnico),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _colorAccent),
                foregroundColor: _colorAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Firmar', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class PdfAvancesGenerator {
  static Future<Uint8List> generatePdf({
    required int folio,
    required String fechaFormateada,
    required String proyectoObra,
    required String clienteContratista,
    required String obraDescripcion,
    required String obraEspecificaciones,
    required List<Uint8List> fotosInicio,
    required List<Uint8List> fotosDurante,
    required List<Uint8List> fotosDespues,
    required String actividadRealizada,
    required String areaNivelObra,
    required List<Map<String, String>> materiales,
    required String descripcionTrabajo,
    required Uint8List firmaTecnico,
    required String nombreTecnico,
    required Uint8List firmaCliente,
    required String nombreCliente,
    required Uint8List logoBytes,
  }) async {
    final pdf = pw.Document();

    pw.Widget buildFotoGrid(String titulo, List<Uint8List> fotos) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (fotos.isEmpty)
            pw.Text('Sin fotos')
          else
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fotos
                  .map<pw.Widget>((img) => pw.Container(
                        width: 90,
                        height: 90,
                        child: pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.cover),
                      ))
                  .toList(),
            ),
        ],
      );
    }

    pw.TableRow buildHeaderRow(List<String> headers) {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headers
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 80,
                height: 80,
                child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HOJA DE SERVICIO',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'COMPAÑÍA DE AIRE ACONDICIONADO Y FRIGORIFICOS DEL SURESTE S.A. DE C.V.',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Teléfono: (999) 102 1232'),
                    pw.Text('Número de identificación empresarial: AAF2306305G0'),
                    pw.Text('Email: contacto@cafrimx.com'),
                    pw.Text('Dirección: C. 59K N°537 POR 112 Y 114 COL. BOJORQUEZ C.P 97230'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),

          pw.Text('1. Datos generales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Proyecto/Obra: $proyectoObra'),
          pw.Text('Cliente/Contratista: $clienteContratista'),
          pw.SizedBox(height: 12),

          pw.Text('2. Obra', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Descripción: $obraDescripcion'),
          pw.SizedBox(height: 4),
          pw.Text('Especificaciones técnicas: $obraEspecificaciones'),
          pw.SizedBox(height: 12),

          pw.Text('3. Avances (fotos)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          buildFotoGrid('Inicio', fotosInicio),
          pw.SizedBox(height: 6),
          buildFotoGrid('Durante', fotosDurante),
          pw.SizedBox(height: 6),
          buildFotoGrid('Después', fotosDespues),
          pw.SizedBox(height: 12),

          pw.Text('4. Reporte del día', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Actividad realizada: $actividadRealizada'),
          pw.Text('Área/Nivel de obra: $areaNivelObra'),
          pw.SizedBox(height: 12),

          pw.Text('5. Resumen de materiales utilizados', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              buildHeaderRow(['Material', 'Unidad', 'Cantidad', 'Observaciones']),
              ...materiales.map(
                (m) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m['material'] ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m['unidad'] ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m['cantidad'] ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m['observaciones'] ?? '')),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          pw.Text('6. Descripción del trabajo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(descripcionTrabajo),
          pw.SizedBox(height: 12),

          pw.Text('7. Firmas', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('Técnico', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Image(pw.MemoryImage(firmaTecnico), height: 80),
                    pw.SizedBox(height: 4),
                    pw.Text(nombreTecnico),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('Cliente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Image(pw.MemoryImage(firmaCliente), height: 80),
                    pw.SizedBox(height: 4),
                    pw.Text(nombreCliente),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'En CAFRI, estamos comprometidos con la reducción del uso de papel y trabajamos continuamente para ser más amigables con el medio ambiente. '
            'Nos esforzamos en la mejora constante y la actualización de nuestros sistemas para minimizar nuestro impacto ecológico.\n\n'
            '(999) 102 1232 / (999) 490 1637   cafrimx.com\n\n'
            'Este documento es propiedad de la empresa CAFRI COMPAÑÍA DE AIRE ACONDICIONADO Y FRIGORIFICOS DEL SURESTE S.A. DE C.V. con domicilio en Calle 59 K, 537 Cp. 97230 en la ciudad de Mérida, Yucatán, '
            'por lo que queda prohibida la reproducción parcial o total de este documento y se tomarán acciones legales.',
            style: pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    return pdf.save();
  }
}