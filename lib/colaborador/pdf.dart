// ignore_for_file: use_build_context_synchronously, unnecessary_nullable_for_final_variable_declarations

import 'dart:typed_data';
import 'package:cafri/helpers/upload_pdf_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart' as ppdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

// Modelo para una hoja/formulario individual (excepto datos de cliente)
class HojaServicioData {
  final TextEditingController descripcionTrabajoRealizadoController =
      TextEditingController();
  final List<MaterialRowData> materiales = [MaterialRowData()];
  final TextEditingController observacionesController =
      TextEditingController(); // NUEVO
  final TextEditingController areaController = TextEditingController();
  final TextEditingController descripcionVaptController =
      TextEditingController();

  final List<Uint8List> fotosVapt = []; // <-- NUEVO
  final List<Uint8List> fotosMantenimientoInicio = [];
  final List<Uint8List> fotosMantenimientoProceso = [];
  final List<Uint8List> fotosMantenimientoFin = [];
  final TextEditingController descripcionInicioController =
      TextEditingController();
  final TextEditingController descripcionProcesoController =
      TextEditingController();
  final TextEditingController descripcionFinController =
      TextEditingController();

  final List<Uint8List> imagenesModeloSerieCapacidad = [];

  Uint8List? firmaTecnico;
  Uint8List? firmaRecibe;
  String? nombreTecnico;
  String? nombreRecibe;

  // Datos del equipo (checkboxes)
  bool sistemaHighWall = false;
  bool sistemaPaquete = false;
  bool sistemaFanCoil = false;
  bool sistemaCasets = false;
  bool sistemaCamaraFria = false;
  bool sistemaPisoTecho = false;
  bool sistemaManejadoraAire = false;
  bool sistemaPaquete2 = false; // duplicado en el listado original

  bool tecnologiaStandar = false;
  bool tecnologiaInverter = false;
  bool tecnologiaVrfVrv = false;
  bool tecnologiaAguaHelada = false;

  final SignatureController firmaTecnicoController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final SignatureController firmaRecibeController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final TextEditingController nombreTecnicoDialogController =
      TextEditingController();
  final TextEditingController nombreRecibeDialogController =
      TextEditingController();

  void dispose() {
    descripcionTrabajoRealizadoController.dispose();
    firmaTecnicoController.dispose();
    firmaRecibeController.dispose();
    nombreTecnicoDialogController.dispose();
    nombreRecibeDialogController.dispose();
    descripcionInicioController.dispose();
    descripcionProcesoController.dispose();
    descripcionFinController.dispose();
    observacionesController.dispose(); // NUEVO
    areaController.dispose();
    for (final m in materiales) {
      m.dispose();
    }
  }

  void clear() {
    descripcionTrabajoRealizadoController.clear();
    firmaTecnico = null;
    firmaRecibe = null;
    nombreTecnico = null;
    nombreRecibe = null;
    firmaTecnicoController.clear();
    firmaRecibeController.clear();
    nombreTecnicoDialogController.clear();
    nombreRecibeDialogController.clear();
    fotosMantenimientoInicio.clear();
    fotosMantenimientoProceso.clear();
    fotosMantenimientoFin.clear();
    descripcionInicioController.clear();
    descripcionProcesoController.clear();
    descripcionFinController.clear();
    imagenesModeloSerieCapacidad.clear();
    observacionesController.clear(); // NUEVO
    areaController.clear();

    sistemaHighWall = false;
    sistemaPaquete = false;
    sistemaFanCoil = false;
    sistemaCasets = false;
    sistemaCamaraFria = false;
    sistemaPisoTecho = false;
    sistemaManejadoraAire = false;
    sistemaPaquete2 = false;
    tecnologiaStandar = false;
    tecnologiaInverter = false;
    tecnologiaVrfVrv = false;
    tecnologiaAguaHelada = false;

    for (final m in materiales) {
      m.dispose();
    }
    materiales
      ..clear()
      ..add(MaterialRowData());
  }

  Map<String, dynamic> toMap() => {
    'area': areaController.text,
    'imagenesModeloSerieCapacidad': imagenesModeloSerieCapacidad,
    'descripcionTrabajoRealizado': descripcionTrabajoRealizadoController.text,
    'materiales': materiales.map((m) => m.toMap()).toList(),
    'observaciones': observacionesController.text, // NUEVO
    'fotosInicio': fotosMantenimientoInicio,
    'descripcionInicio': descripcionInicioController.text,
    'fotosProceso': fotosMantenimientoProceso,
    'descripcionProceso': descripcionProcesoController.text,
    'fotosFin': fotosMantenimientoFin,
    'descripcionFin': descripcionFinController.text,
    'firmaTecnico': firmaTecnico,
    'nombreTecnico': nombreTecnico,
    'firmaRecibe': firmaRecibe,
    'nombreRecibe': nombreRecibe,
    'fotosVapt': fotosVapt,
    'descripcionVapt': descripcionVaptController.text,
    'sistemaHighWall': sistemaHighWall,
    'sistemaPaquete': sistemaPaquete,
    'sistemaFanCoil': sistemaFanCoil,
    'sistemaCasets': sistemaCasets,
    'sistemaCamaraFria': sistemaCamaraFria,
    'sistemaPisoTecho': sistemaPisoTecho,
    'sistemaManejadoraAire': sistemaManejadoraAire,
    'sistemaPaquete2': sistemaPaquete2,
    'tecnologiaStandar': tecnologiaStandar,
    'tecnologiaInverter': tecnologiaInverter,
    'tecnologiaVrfVrv': tecnologiaVrfVrv,
    'tecnologiaAguaHelada': tecnologiaAguaHelada,
  };
}

class FormularioPDF extends StatefulWidget {
  // Se agregan valores iniciales para prellenar campos
  const FormularioPDF({
    super.key,
    this.initialNombreCliente,
    this.initialAtencion,
  });

  final String? initialNombreCliente;
  final String? initialAtencion;

  @override
  State<FormularioPDF> createState() => _FormularioPDFState();
}

class _FormularioPDFState extends State<FormularioPDF> {
  static const _colorSurface = Color(0xFFF3F6FB);
  static const _colorCard = Colors.white;
  static const _colorHeader = Color(0xFF0F4C81);
  static const _colorAccent = Color(0xFF1D9A6C);
  static const double _photoThumbSize = 90;
  static const double _photoGap = 12;

  // Campos de cliente (únicos)
  final TextEditingController campoNombreCliente = TextEditingController();
  final TextEditingController responsableGlobal = TextEditingController();

  // Lista dinámica de hojas (formularios)
  final List<HojaServicioData> hojas = [HojaServicioData()];

  int? folioActual;
  bool cargandoFolio = true;

  @override
  void initState() {
    super.initState();
    _cargarFolio();

    // Prefill desde los parámetros del widget (si vienen)
    final n = widget.initialNombreCliente;
    final a = widget.initialAtencion;
    if (n != null && n.isNotEmpty) {
      campoNombreCliente.text = n;
    }
    if (a != null && a.isNotEmpty && hojas.isNotEmpty) {
      hojas.first.areaController.text = a;
    }
  }

  @override
  void dispose() {
    for (final hoja in hojas) {
      hoja.dispose();
    }
    campoNombreCliente.dispose();
    responsableGlobal.dispose();
    super.dispose();
  }

  String? validarCamposObligatorios() {
    // Campos de cliente
    if (campoNombreCliente.text.trim().isEmpty) {
      return 'Nombre del cliente es obligatorio.';
    }
    if (responsableGlobal.text.trim().isEmpty) {
      return 'Nombre del responsable es obligatorio.';
    }

    // Por cada hoja
    for (int i = 0; i < hojas.length; i++) {
      final hoja = hojas[i];
      final noHoja = i + 1;

      if (hoja.fotosMantenimientoInicio.isEmpty) {
        return 'Hoja $noHoja: Sube al menos 1 foto de inicio.';
      }
      if (hoja.fotosMantenimientoProceso.isEmpty) {
        return 'Hoja $noHoja: Sube al menos 1 foto de proceso.';
      }
      if (hoja.fotosMantenimientoFin.isEmpty) {
        return 'Hoja $noHoja: Sube al menos 1 foto de fin.';
      }

      if (hoja.descripcionTrabajoRealizadoController.text.trim().isEmpty) {
        return 'Hoja $noHoja: Describe el trabajo realizado.';
      }

      if (hoja.firmaTecnico == null) {
        return 'Hoja $noHoja: Falta la firma del técnico.';
      }
      if (hoja.nombreTecnico == null || hoja.nombreTecnico!.trim().isEmpty) {
        return 'Hoja $noHoja: Falta el nombre del técnico.';
      }
      if (hoja.firmaRecibe == null) {
        return 'Hoja $noHoja: Falta la firma de quien recibe.';
      }
      if (hoja.nombreRecibe == null || hoja.nombreRecibe!.trim().isEmpty) {
        return 'Hoja $noHoja: Falta el nombre de quien recibe.';
      }
    }

    return null;
  }

  Future<void> _cargarFolio() async {
    final folio = await FolioService.getNextFolio();
    setState(() {
      folioActual = folio;
      cargandoFolio = false;
    });
  }

  void _limpiarFormulario() {
    campoNombreCliente.clear();
    responsableGlobal.clear();
    for (final hoja in hojas) {
      hoja.dispose();
    }
    hojas
      ..clear()
      ..add(HojaServicioData());
  }

  Future<void> _agregarHoja() async {
    final nueva = HojaServicioData();
    final base = hojas.isNotEmpty ? hojas.last : null;

    if (base != null && base.areaController.text.trim().isNotEmpty) {
      nueva.areaController.text = base.areaController.text;
    }

    if (base != null &&
        (base.firmaTecnico != null || base.firmaRecibe != null)) {
      final usarMismas = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Usar las mismas firmas?'),
          content: const Text(
            'Se detectaron firmas en la hoja anterior. ¿Quieres reutilizarlas en la nueva hoja?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nuevas'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Usar mismas'),
            ),
          ],
        ),
      );

      if (usarMismas == null) return;
      if (usarMismas) {
        nueva.firmaTecnico = base.firmaTecnico;
        nueva.nombreTecnico = base.nombreTecnico;
        nueva.firmaRecibe = base.firmaRecibe;
        nueva.nombreRecibe = base.nombreRecibe;
        if (base.nombreTecnico != null) {
          nueva.nombreTecnicoDialogController.text = base.nombreTecnico!;
        }
        if (base.nombreRecibe != null) {
          nueva.nombreRecibeDialogController.text = base.nombreRecibe!;
        }
      }
    }

    setState(() {
      hojas.add(nueva);
    });
  }

  Widget _hojasWidget() {
    return Column(
      children: [
        ...hojas.asMap().entries.map((entry) {
          final idx = entry.key;
          final hoja = entry.value;
          return Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Hoja ${idx + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      if (hojas.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              hoja.dispose();
                              hojas.removeAt(idx);
                            });
                          },
                        ),
                    ],
                  ),
                  // Actividades
                  // Imagen modelo, serie y capacidad
                  _seccionFormulario(
                    titulo: 'Área',
                    icon: Icons.place_outlined,
                    child: TextField(
                      controller: hoja.areaController,
                      decoration: _inputDecoration('Área'),
                    ),
                  ),
                  _datosEquipoWidget(hoja),
                  const SizedBox(height: 8),
                  _modeloSerieCapacidadImagenWidget(hoja),
                  const SizedBox(height: 8),
                  FotosFilaDescripcion(
                    titulo: '4. VOLTAJES, AMPERAJES, PRESIONES Y TEMPERATURAS',
                    icon: Icons.electrical_services_outlined,
                    fotos: hoja.fotosVapt,
                    descripcionController: hoja.descripcionVaptController,
                    onAdd: (img) => setState(() => hoja.fotosVapt.add(img)),
                    onRemove: (idx) =>
                        setState(() => hoja.fotosVapt.removeAt(idx)),
                  ),
                  const SizedBox(height: 8),

                  // Fotos inicio/proceso/fin (nuevo widget)
                  FotosFilaDescripcion(
                    titulo: '5. Fotos de inicio',
                    icon: Icons.photo_camera_outlined,
                    fotos: hoja.fotosMantenimientoInicio,
                    descripcionController: hoja.descripcionInicioController,
                    onAdd: (img) =>
                        setState(() => hoja.fotosMantenimientoInicio.add(img)),
                    onRemove: (idx) => setState(
                      () => hoja.fotosMantenimientoInicio.removeAt(idx),
                    ),
                  ),
                  FotosFilaDescripcion(
                    titulo: '6. Fotos de proceso',
                    icon: Icons.photo_camera_outlined,
                    fotos: hoja.fotosMantenimientoProceso,
                    descripcionController: hoja.descripcionProcesoController,
                    onAdd: (img) =>
                        setState(() => hoja.fotosMantenimientoProceso.add(img)),
                    onRemove: (idx) => setState(
                      () => hoja.fotosMantenimientoProceso.removeAt(idx),
                    ),
                  ),
                  FotosFilaDescripcion(
                    titulo: '7. Fotos de fin',
                    icon: Icons.photo_camera_outlined,
                    fotos: hoja.fotosMantenimientoFin,
                    descripcionController: hoja.descripcionFinController,
                    onAdd: (img) =>
                        setState(() => hoja.fotosMantenimientoFin.add(img)),
                    onRemove: (idx) => setState(
                      () => hoja.fotosMantenimientoFin.removeAt(idx),
                    ),
                  ),
                  _seccionFormulario(
                    titulo: '6. Descripción del trabajo',
                    icon: Icons.description_outlined,
                    child: TextField(
                      controller: hoja.descripcionTrabajoRealizadoController,
                      decoration: _inputDecoration(
                        'Describe el trabajo realizado',
                      ),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _seccionFormulario(
                    titulo: '5. materiales utilizados',
                    icon: Icons.inventory_2_outlined,
                    child: _materialesWidget(hoja),
                  ),
                  const SizedBox(height: 8),
                  // NUEVO: Observaciones
                  TextField(
                    controller: hoja.observacionesController,
                    decoration: _inputDecoration('Observaciones'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _seccionFormulario(
                    titulo: '7. Firmas',
                    icon: Icons.draw_outlined,
                    child: Row(
                      children: [
                        Expanded(
                          child: _firmaWidget(
                            titulo: 'Firma del técnico',
                            firma: hoja.firmaTecnico,
                            nombre: hoja.nombreTecnico,
                            onFirmar: () => _firmar(
                              hoja.firmaTecnicoController,
                              'Firma del técnico',
                              hoja.nombreTecnicoDialogController,
                              true,
                              hoja,
                            ),
                            onEliminar: () => _eliminarFirma(true, hoja),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _firmaWidget(
                            titulo: 'Firma de quien recibe',
                            firma: hoja.firmaRecibe,
                            nombre: hoja.nombreRecibe,
                            onFirmar: () => _firmar(
                              hoja.firmaRecibeController,
                              'Firma de quien recibe',
                              hoja.nombreRecibeDialogController,
                              false,
                              hoja,
                            ),
                            onEliminar: () => _eliminarFirma(false, hoja),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Agregar otra hoja'),
            onPressed: _agregarHoja,
          ),
        ),
      ],
    );
  }

  Widget _modeloSerieCapacidadImagenWidget(HojaServicioData hoja) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloBloque(
          '2. MODELO, SERIE, CAPACIDAD DE CONDENSADOR Y CAPACITOR',
          icon: Icons.confirmation_number_outlined,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: _photoGap,
          runSpacing: _photoGap,
          children: [
            ...hoja.imagenesModeloSerieCapacidad.map(
              (imgBytes) => Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imgBytes,
                      width: _photoThumbSize,
                      height: _photoThumbSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        hoja.imagenesModeloSerieCapacidad.remove(imgBytes);
                      });
                    },
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final List<XFile>? pickedList = await picker.pickMultiImage(
                  maxWidth: 1280,
                  maxHeight: 1280,
                  imageQuality: 75,
                );
                if (pickedList != null && pickedList.isNotEmpty) {
                  final bytesList = await Future.wait(
                    pickedList.map((xfile) => xfile.readAsBytes()),
                  );
                  setState(() {
                    hoja.imagenesModeloSerieCapacidad.addAll(bytesList);
                  });
                }
              },
              child: Container(
                width: _photoThumbSize,
                height: _photoThumbSize,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  size: 32,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _datosEquipoWidget(HojaServicioData hoja) {
    Widget checkboxItem(String label, bool value, void Function(bool?) onChanged) {
      return SizedBox(
        width: 170,
        child: Row(
          children: [
            Checkbox(value: value, onChanged: onChanged),
            Expanded(child: Text(label)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloBloque('1. DATOS DEL EQUIPO', icon: Icons.settings_outlined),
        const SizedBox(height: 8),
        const Text(
          'Tipo de sistema',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            checkboxItem(
              'High Wall',
              hoja.sistemaHighWall,
              (v) => setState(() => hoja.sistemaHighWall = v ?? false),
            ),
            checkboxItem(
              'Paquete',
              hoja.sistemaPaquete,
              (v) => setState(() => hoja.sistemaPaquete = v ?? false),
            ),
            checkboxItem(
              'Fan & Coil',
              hoja.sistemaFanCoil,
              (v) => setState(() => hoja.sistemaFanCoil = v ?? false),
            ),
            checkboxItem(
              'Casets',
              hoja.sistemaCasets,
              (v) => setState(() => hoja.sistemaCasets = v ?? false),
            ),
            checkboxItem(
              'Cámara fría',
              hoja.sistemaCamaraFria,
              (v) => setState(() => hoja.sistemaCamaraFria = v ?? false),
            ),
            checkboxItem(
              'Piso-Techo',
              hoja.sistemaPisoTecho,
              (v) => setState(() => hoja.sistemaPisoTecho = v ?? false),
            ),
            checkboxItem(
              'Manejadora de Aire',
              hoja.sistemaManejadoraAire,
              (v) => setState(() => hoja.sistemaManejadoraAire = v ?? false),
            ),
            checkboxItem(
              'Paquete',
              hoja.sistemaPaquete2,
              (v) => setState(() => hoja.sistemaPaquete2 = v ?? false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tecnologí­a',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            checkboxItem(
              'Standar',
              hoja.tecnologiaStandar,
              (v) => setState(() => hoja.tecnologiaStandar = v ?? false),
            ),
            checkboxItem(
              'Inverter',
              hoja.tecnologiaInverter,
              (v) => setState(() => hoja.tecnologiaInverter = v ?? false),
            ),
            checkboxItem(
              'VRF/VRV',
              hoja.tecnologiaVrfVrv,
              (v) => setState(() => hoja.tecnologiaVrfVrv = v ?? false),
            ),
            checkboxItem(
              'Agua Helada',
              hoja.tecnologiaAguaHelada,
              (v) => setState(() => hoja.tecnologiaAguaHelada = v ?? false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _materialesWidget(HojaServicioData hoja) {
    InputDecoration denseInput(String hint) => InputDecoration(
      hintText: hint,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 860.0;
        final tableWidth = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Material',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Unidad',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Cantidad',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Observaciones',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 36),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...hoja.materiales.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: e.value.material,
                                decoration: denseInput('Material o insumo'),
                                minLines: 1,
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: e.value.unidad,
                                decoration: denseInput('Unidad'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: e.value.cantidad,
                                decoration: denseInput('Cantidad'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: e.value.observaciones,
                                decoration: denseInput('Observaciones'),
                                minLines: 1,
                                maxLines: 2,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              padding: const EdgeInsets.only(left: 4, right: 4, top: 6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                setState(() {
                                  if (hoja.materiales.length > 1) {
                                    final row = hoja.materiales.removeAt(e.key);
                                    row.dispose();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => hoja.materiales.add(MaterialRowData())),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agregar material'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _firmaWidget({
    required String titulo,
    required Uint8List? firma,
    required String? nombre,
    required VoidCallback onFirmar,
    required VoidCallback onEliminar,
  }) {
    return Column(
      children: [
        _tituloBloque(titulo),
        const SizedBox(height: 4),
        if (firma != null)
          Column(
            children: [
              Image.memory(firma, height: 100),
              if (nombre != null) Text(nombre),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Eliminar firma',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: onEliminar,
              ),
            ],
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Firmar'),
            onPressed: onFirmar,
          ),
      ],
    );
  }

  Future<void> _firmar(
    SignatureController controller,
    String titulo,
    TextEditingController nombreController,
    bool esTecnico,
    HojaServicioData hoja,
  ) async {
    if (esTecnico && hoja.nombreTecnico != null) {
      nombreController.text = hoja.nombreTecnico!;
    } else if (!esTecnico && hoja.nombreRecibe != null) {
      nombreController.text = hoja.nombreRecibe!;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(titulo),
              content: AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: Signature(
                          controller: controller,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    controller.clear();
                    setDialogState(() {}); // refresca el diálogo
                  },
                  child: const Text('Limpiar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (controller.isNotEmpty &&
                        nombreController.text.trim().isNotEmpty) {
                      final signature = await controller.toPngBytes();
                      Navigator.of(context).pop({
                        'firma': signature,
                        'nombre': nombreController.text.trim(),
                      });
                    } else {
                      // Mostrar mensaje si falta firma o nombre
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La firma y el nombre son obligatorios.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
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
          hoja.firmaTecnico = result['firma'];
          hoja.nombreTecnico = result['nombre'];
        } else {
          hoja.firmaRecibe = result['firma'];
          hoja.nombreRecibe = result['nombre'];
        }

        for (final h in hojas) {
          if (h == hoja) continue;
          if (esTecnico && h.firmaTecnico == null) {
            h.firmaTecnico = result['firma'];
            h.nombreTecnico = result['nombre'];
            h.nombreTecnicoDialogController.text = result['nombre'];
          } else if (!esTecnico && h.firmaRecibe == null) {
            h.firmaRecibe = result['firma'];
            h.nombreRecibe = result['nombre'];
            h.nombreRecibeDialogController.text = result['nombre'];
          }
        }
      });
    }
  }

  void _eliminarFirma(bool esTecnico, HojaServicioData hoja) {
    setState(() {
      if (esTecnico) {
        hoja.firmaTecnico = null;
        hoja.nombreTecnico = null;
        hoja.firmaTecnicoController.clear();
        hoja.nombreTecnicoDialogController.clear();
      } else {
        hoja.firmaRecibe = null;
        hoja.nombreRecibe = null;
        hoja.firmaRecibeController.clear();
        hoja.nombreRecibeDialogController.clear();
      }
    });
  }

  Widget _encabezadoCafri() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF155D9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F4C81),
            blurRadius: 18,
            offset: Offset(0, 8),
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
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HOJA DE SERVICIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'COMPAÑÍA DE AIRE ACONDICIONADO Y FRIGORIFICOS DEL SURESTE S.A. DE C.V.',
                  style: TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text('Teléfono: (999) 102 1232', style: TextStyle(color: Color(0xFFEAF2FF))),
                Text(
                  'Número de identificación empresarial: AAF2306305G0',
                  style: TextStyle(color: Color(0xFFEAF2FF)),
                ),
                Text('Email: contacto@cafrimx.com', style: TextStyle(color: Color(0xFFEAF2FF))),
                Text(
                  'Dirección: C. 59K N°537 POR 112 Y 114 COL. BOJORQUEZ C.P 97230',
                  style: TextStyle(color: Color(0xFFEAF2FF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionConTitulo(String titulo, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _colorCard,
        border: Border.all(color: const Color(0xFFD5DFEC)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: const BoxDecoration(
              color: _colorHeader,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14.0), child: child),
        ],
      ),
    );
  }

  Widget _seccionFormulario({
    required String titulo,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _colorCard,
        border: Border.all(color: const Color(0xFFD5DFEC)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: _colorHeader,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14.0), child: child),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _tituloBloque(String titulo, {IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _colorHeader,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              titulo.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaActual = DateTime.now();
    final fechaFormateada =
        '${fechaActual.day.toString().padLeft(2, '0')}/'
        '${fechaActual.month.toString().padLeft(2, '0')}/'
        '${fechaActual.year} '
        '${fechaActual.hour.toString().padLeft(2, '0')}:'
        '${fechaActual.minute.toString().padLeft(2, '0')}';

    if (cargandoFolio || folioActual == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _colorSurface,
      appBar: AppBar(
        title: const Text('Hoja de servicio'),
        elevation: 0,
        backgroundColor: _colorHeader,
        foregroundColor: Colors.white,
      ),
      body: AnimatedPadding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                children: [
                  _encabezadoCafri(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _colorCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD5DFEC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined),
                        const SizedBox(width: 8),
                        const Text(
                          'Folio (Tarea): ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          folioActual.toString(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: campoNombreCliente,
                    decoration: _inputDecoration('Nombre del cliente'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: responsableGlobal,
                    decoration: _inputDecoration('Nombre del responsable'),
                  ),
                  const SizedBox(height: 16),
                  _seccionConTitulo('Hojas de servicio', _hojasWidget()),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Guardar como PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        // 1. Primero valida los campos obligatorios
                        final error = validarCamposObligatorios();
                        if (error != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                          return; // Detén el flujo si faltan campos
                        }

                        // 2. Ahora sí, pide confirmación
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmar generación de PDF'),
                            content: const Text(
                              'Estás a punto de generar el PDF. ¿Está todo correcto?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Sí, continuar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;

                        // Mostrar indicador de progreso
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
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Generando y enviando PDF...'),
                                ],
                              ),
                            ),
                          ),
                        );

                        try {
                          final logoBytes = await rootBundle.load(
                            'lib/assets/cafrilogo.png',
                          );
                          final logoUint8List = logoBytes.buffer.asUint8List();

                          final hojasList = hojas
                              .map((h) => h.toMap())
                              .toList();

                          // --- CAMBIO CLAVE: Guarda el folio actual en una variable local ---
                          final folioParaPDF = folioActual!;

                          final pdfBytes = await PdfGenerator.generatePdf(
                            folio: folioParaPDF,
                            nombreCliente: campoNombreCliente.text,
                            responsable: responsableGlobal.text,
                            hojas: hojasList,
                            fechaFormateada: fechaFormateada,
                            logoBytes: logoUint8List,
                          );

                          // Validar que el PDF se generó correctamente
                          if (pdfBytes.isEmpty) {
                            throw Exception('El PDF generado está vací­o');
                          }

                          try {
                            await subirPdfTarea(
                              pdfBytes,
                              folioParaPDF,
                              nombreCliente: campoNombreCliente.text,
                            );
                          } catch (e) {
                            // Error al subir, pero puede estar en cola
                            final errorMsg = e.toString();
                            if (mounted) {
                              Navigator.of(
                                context,
                              ).pop(); // Cerrar diálogo de progreso
                            }

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            return;
                          }

                          // Si llegamos aquí, la subida fue exitosa
                          await FolioService.updateFolio(folioParaPDF);

                          if (mounted) {
                            Navigator.of(
                              context,
                            ).pop(); // Cerrar diálogo de progreso
                          }

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✓ PDF enviado exitosamente\nFolio: $folioParaPDF',
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );

                          setState(() {
                            folioActual = folioParaPDF + 1;
                            _limpiarFormulario();
                          });

                          await Printing.layoutPdf(
                            onLayout: (format) async => pdfBytes,
                            name: 'Tarea($folioParaPDF).pdf',
                          );
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(
                              context,
                            ).pop(); // Cerrar diálogo de progreso
                          }

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
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
      ),
    );
  }
}

// Widget para lista de fotos en fila y una sola Descripción
class FotosFilaDescripcion extends StatefulWidget {
  final String titulo;
  final List<Uint8List> fotos;
  final TextEditingController descripcionController;
  final void Function(Uint8List) onAdd;
  final void Function(int) onRemove;
  final IconData? icon;

  const FotosFilaDescripcion({
    super.key,
    required this.titulo,
    required this.fotos,
    required this.descripcionController,
    required this.onAdd,
    required this.onRemove,
    this.icon,
  });

  @override
  State<FotosFilaDescripcion> createState() => _FotosFilaDescripcionState();
}

class _FotosFilaDescripcionState extends State<FotosFilaDescripcion> {
  static const double _photoThumbSize = 90;
  static const double _photoGap = 12;
  static const _titleBg = Color(0xFF0F4C81);

  Future<void> _agregarFoto() async {
    final picker = ImagePicker();
    final List<XFile>? pickedList = await picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (pickedList != null && pickedList.isNotEmpty) {
      final bytesList = await Future.wait(
        pickedList.map((xfile) => xfile.readAsBytes()),
      );
      for (final bytes in bytesList) {
        widget.onAdd(bytes);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _titleBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.titulo.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: _photoGap,
          runSpacing: _photoGap,
          children: [
            ...widget.fotos.asMap().entries.map((entry) {
              final idx = entry.key;
              final imgBytes = entry.value;
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imgBytes,
                      width: _photoThumbSize,
                      height: _photoThumbSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                    onPressed: () {
                      widget.onRemove(idx);
                      setState(() {});
                    },
                  ),
                ],
              );
            }),
            GestureDetector(
              onTap: _agregarFoto,
              child: Container(
                width: _photoThumbSize,
                height: _photoThumbSize,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  size: 32,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.descripcionController,
          decoration: InputDecoration(
            labelText: 'Descripción',
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black12),
            ),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}

// Generador de PDF multipágina
class PdfGenerator {
  static const double _pdfModelImageSize = 90;
  static const double _pdfPhotoSize = _pdfModelImageSize;
  static const double _pdfPhotoGap = 12;

  static Future<Uint8List> generatePdf({
    required int folio,
    required String nombreCliente,
    required String responsable,
    required List<Map<String, dynamic>> hojas,
    required String fechaFormateada,
    required Uint8List logoBytes,
  }) async {
    final fontData = await rootBundle.load(
      'packages/syncfusion_flutter_pdfviewer/assets/fonts/RobotoMono-Regular.ttf',
    );
    final baseFont = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: baseFont,
    );
    final pdf = pw.Document(theme: theme);
    final headerColor = ppdf.PdfColor.fromInt(0xFF0F4C81);
    final borderColor = ppdf.PdfColor.fromInt(0xFFD5DFEC);
    final lightBg = ppdf.PdfColor.fromInt(0xFFF8FAFD);

    pw.Widget buildPdfTitulo(String titulo) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: headerColor,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          titulo.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: ppdf.PdfColor.fromInt(0xFFFFFFFF),
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    pw.Widget buildCardSection(String titulo, List<pw.Widget> children) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderColor),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildPdfTitulo(titulo),
              pw.SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );
    }

    pw.Widget buildFotoFila(List fotos, String descripcion, String titulo) {
      if (fotos.isEmpty) {
        return buildCardSection(
          titulo,
          [
            pw.Text('No hay fotos agregadas.'),
            if (descripcion.isNotEmpty) pw.SizedBox(height: 4),
            if (descripcion.isNotEmpty)
              pw.Text(
                descripcion,
                style: pw.TextStyle(fontSize: 10),
              ),
          ],
        );
      }
      return buildCardSection(
        titulo,
        [
          pw.Wrap(
            spacing: _pdfPhotoGap,
            runSpacing: _pdfPhotoGap,
            children: fotos.map<pw.Widget>((imgBytes) {
              return pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Container(
                  width: _pdfPhotoSize,
                  height: _pdfPhotoSize,
                  child: pw.Image(
                    pw.MemoryImage(imgBytes),
                    fit: pw.BoxFit.cover,
                  ),
                ),
              );
            }).toList(),
          ),
          if (descripcion.isNotEmpty) pw.SizedBox(height: 4),
          if (descripcion.isNotEmpty)
            pw.Text(
              descripcion,
              style: pw.TextStyle(fontSize: 10),
            ),
        ],
      );
    }

    pw.Widget buildCheckboxItem(String label, bool checked, {double width = 160}) {
      return pw.Container(
        width: width,
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          children: [
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: ppdf.PdfColors.black),
              ),
              child: checked
                  ? pw.Center(
                      child: pw.Text(
                        'X',
                        style: pw.TextStyle(fontSize: 8),
                      ),
                    )
                  : pw.SizedBox(),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 10))),
          ],
        ),
      );
    }

    pw.TableRow buildHeaderRow(List<String> headers) {
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: lightBg),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            )
            .toList(),
      );
    }

    // Header and footer builders
    pw.Widget buildPdfHeader(Uint8List logo, String fecha, int folio, String cliente) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 62,
                height: 62,
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Image(
                  pw.MemoryImage(logo),
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HOJA DE SERVICIO',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'COMPAÑÍA DE AIRE ACONDICIONADO Y FRIGORIFICOS DEL SURESTE S.A. DE C.V.',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.Text('Teléfono: (999) 102 1232', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Número de identificación empresarial: AAF2306305G0', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Email: contacto@cafrimx.com', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Dirección: C. 59K N°537 POR 112 Y 114 COL. BOJORQUEZ C.P 97230', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Folio (Tarea): $folio', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Cliente: $cliente', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1),
        ],
      );
    }

    pw.Widget buildPdfFooter(pw.Context context) {
      return pw.Column(
        children: [
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CAFRI confidencial',
                style: const pw.TextStyle(fontSize: 9, color: ppdf.PdfColor.fromInt(0xFF777777)),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: ppdf.PdfColor.fromInt(0xFF777777)),
              ),
            ],
          ),
        ],
      );
    }

    for (final hoja in hojas) {
      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(24),
          header: (context) => buildPdfHeader(logoBytes, fechaFormateada, folio, nombreCliente),
          footer: (context) => buildPdfFooter(context),
          build: (context) => [
            buildCardSection(
              'Información del cliente',
              [
                pw.Text('Nombre del cliente: $nombreCliente'),
                pw.Text('Nombre del responsable: $responsable'),
                pw.Text('Área: ${hoja['Área'] ?? ''}'),
              ],
            ),

            buildCardSection(
              'DATOS DEL EQUIPO',
              [
                pw.Text('Tipo de sistema:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    buildCheckboxItem('High Wall', hoja['sistemaHighWall'] == true),
                    buildCheckboxItem('Paquete', hoja['sistemaPaquete'] == true),
                    buildCheckboxItem('Fan & Coil', hoja['sistemaFanCoil'] == true),
                    buildCheckboxItem('Casets', hoja['sistemaCasets'] == true),
                    buildCheckboxItem('Cámara fría', hoja['sistemaCamaraFria'] == true),
                    buildCheckboxItem('Piso-Techo', hoja['sistemaPisoTecho'] == true),
                    buildCheckboxItem('Manejadora de Aire', hoja['sistemaManejadoraAire'] == true, width: 200),
                    buildCheckboxItem('Paquete', hoja['sistemaPaquete2'] == true),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text('Tecnología:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    buildCheckboxItem('Standar', hoja['tecnologiaStandar'] == true),
                    buildCheckboxItem('Inverter', hoja['tecnologiaInverter'] == true),
                    buildCheckboxItem('VRF/VRV', hoja['tecnologiaVrfVrv'] == true),
                    buildCheckboxItem('Agua Helada', hoja['tecnologiaAguaHelada'] == true),
                  ],
                ),
              ],
            ),

            buildCardSection(
              'MODELO, SERIE, CAPACIDAD DE CONDENSADOR Y CAPACITOR',
              [
                if ((hoja['imagenesModeloSerieCapacidad'] ?? []).isNotEmpty)
                  pw.Wrap(
                    spacing: _pdfPhotoGap,
                    runSpacing: _pdfPhotoGap,
                    children: (hoja['imagenesModeloSerieCapacidad'] as List)
                        .map<pw.Widget>(
                          (imgBytes) => pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(
                              pw.MemoryImage(imgBytes),
                              width: _pdfModelImageSize,
                              height: _pdfModelImageSize,
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        )
                        .toList(),
                  )
                else
                  pw.Text('No hay imagen agregada.'),
              ],
            ),

            buildFotoFila(
              (hoja['fotosVapt'] ?? []) as List,
              hoja['descripcionVapt'] ?? '',
              'VOLTAJES, AMPERAJES, PRESIONES Y TEMPERATURAS (fotos)',
            ),

            buildFotoFila(
              (hoja['fotosInicio'] ?? []) as List,
              hoja['descripcionInicio'] ?? '',
              'Fotos de inicio del servicio',
            ),
            buildFotoFila(
              (hoja['fotosProceso'] ?? []) as List,
              hoja['descripcionProceso'] ?? '',
              'Fotos de proceso del servicio',
            ),
            buildFotoFila(
              (hoja['fotosFin'] ?? []) as List,
              hoja['descripcionFin'] ?? '',
              'Fotos de fin del servicio',
            ),

            buildCardSection(
              'Descripción del trabajo realizado',
              [
                pw.Text(hoja['descripcionTrabajoRealizado'] ?? ''),
              ],
            ),

            buildCardSection(
              'materiales utilizados',
              [
                if ((hoja['materiales'] ?? []).isEmpty)
                  pw.Text('Sin materiales')
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: ppdf.PdfColors.grey400),
                    children: [
                      buildHeaderRow(['Material', 'Unidad', 'Cantidad', 'Observaciones']),
                      ...(hoja['materiales'] as List).map(
                        (m) {
                          final row = Map<String, dynamic>.from(m as Map);
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(row['material'] ?? ''),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(row['unidad'] ?? ''),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(row['cantidad'] ?? ''),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(row['observaciones'] ?? ''),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),

            buildCardSection(
              'Observaciones',
              [
                pw.Text(hoja['observaciones'] ?? ''),
              ],
            ),

            buildCardSection(
              'Firmas',
              [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Firma del técnico', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          if (hoja['firmaTecnico'] != null)
                            pw.Image(
                              pw.MemoryImage(hoja['firmaTecnico']),
                              height: 100,
                            ),
                          if (hoja['nombreTecnico'] != null)
                            pw.Text(hoja['nombreTecnico']),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Firma de quien recibe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          if (hoja['firmaRecibe'] != null)
                            pw.Image(
                              pw.MemoryImage(hoja['firmaRecibe']),
                              height: 100,
                            ),
                          if (hoja['nombreRecibe'] != null)
                            pw.Text(hoja['nombreRecibe']),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    }

    return pdf.save();
  }
}

//las imagenes multiple seleccion
