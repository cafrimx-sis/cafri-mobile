// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cafri/helpers/upload_pdf_storage.dart';
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

class _FormularioAvancesPDFState extends State<FormularioAvancesPDF> {
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

  @override
  void initState() {
    super.initState();
    _cargarFolio();
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

  String? _validar() {
    if (proyectoObra.text.trim().isEmpty) return 'Proyecto/Obra es obligatorio';
    if (clienteContratista.text.trim().isEmpty) {
      return 'Cliente/Contratista es obligatorio';
    }
    if (actividadRealizada.text.trim().isEmpty) {
      return 'Actividad realizada es obligatorio';
    }
    if (areaNivelObra.text.trim().isEmpty) {
      return 'Área/Nivel de obra es obligatorio';
    }
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
              title: Text(esTecnico ? 'Firma del técnico' : 'Firma del cliente'),
              content: SizedBox(
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
              actions: [
                TextButton(
                  onPressed: () {
                    controller.clear();
                    setDialogState(() {});
                  },
                  child: const Text('Limpiar'),
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
          firmaTecnico = result['firma'];
        } else {
          firmaCliente = result['firma'];
        }
      });
    }
  }

  Future<void> _agregarFotos(List<Uint8List> destino) async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage();
    if (pickedList.isNotEmpty) {
      final bytesList = await Future.wait(pickedList.map((x) => x.readAsBytes()));
      setState(() => destino.addAll(bytesList));
    }
  }

  Widget _seccionConTitulo(String titulo, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12.0), child: child),
        ],
      ),
    );
  }

  Widget _encabezadoCafri() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
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
                  'REPORTE DE AVANCES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'COMPAÑÍA DE AIRE ACONDICIONADO Y FRIGORIFICOS DEL SURESTE S.A. DE C.V.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text('Teléfono: (999) 102 1232'),
                Text('Número de identificación empresarial: AAF2306305G0'),
                Text('Email: contacto@cafrimx.com'),
                Text(
                  'Dirección: C. 59K N°537 POR 112 Y 114 COL. BOJORQUEZ C.P 97230',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotosSeccion(String titulo, List<Uint8List> fotos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...fotos.asMap().entries.map((entry) {
              final idx = entry.key;
              final imgBytes = entry.value;
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imgBytes,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                    onPressed: () => setState(() => fotos.removeAt(idx)),
                  ),
                ],
              );
            }),
            GestureDetector(
              onTap: () => _agregarFotos(fotos),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaActual = DateTime.now();
    final fechaFormateada = '${fechaActual.day.toString().padLeft(2, '0')}/${fechaActual.month.toString().padLeft(2, '0')}/${fechaActual.year} ${fechaActual.hour.toString().padLeft(2, '0')}:${fechaActual.minute.toString().padLeft(2, '0')}';

    if (cargandoFolio || folioActual == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de Avances - PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _encabezadoCafri(),
              Row(
                children: [
                  const Text('Folio (Avance): ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${folioActual!}')
                ],
              ),
              const SizedBox(height: 8),
              Text('Fecha: $fechaFormateada'),
              const SizedBox(height: 16),
              _seccionConTitulo(
                '1. Datos generales',
                Column(
                  children: [
                    TextField(
                      controller: proyectoObra,
                      decoration: const InputDecoration(labelText: 'Proyecto/Obra'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clienteContratista,
                      decoration: const InputDecoration(labelText: 'Cliente/Contratista'),
                    ),
                  ],
                ),
              ),
              _seccionConTitulo(
                '2. Obra',
                Column(
                  children: [
                    TextField(
                      controller: obraDescripcion,
                      decoration: const InputDecoration(labelText: 'Descripción de la obra'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: obraEspecificaciones,
                      decoration: const InputDecoration(labelText: 'Especificaciones técnicas'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              _seccionConTitulo(
                '3. Avances (fotos)',
                Column(
                  children: [
                    _fotosSeccion('Inicio', fotosInicio),
                    const SizedBox(height: 12),
                    _fotosSeccion('Durante', fotosDurante),
                    const SizedBox(height: 12),
                    _fotosSeccion('Después', fotosDespues),
                  ],
                ),
              ),
              _seccionConTitulo(
                '4. Reporte del día',
                Column(
                  children: [
                    TextField(
                      controller: actividadRealizada,
                      decoration: const InputDecoration(labelText: 'Actividad realizada'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: areaNivelObra,
                      decoration: const InputDecoration(labelText: 'Área/Nivel de obra'),
                    ),
                  ],
                ),
              ),
              _seccionConTitulo(
                '5. Resumen de materiales utilizados',
                Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        SizedBox(width: 90, child: Text('Unidad', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        SizedBox(width: 90, child: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Expanded(child: Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...materiales.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: e.value.material,
                                decoration: const InputDecoration(hintText: 'Material'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: e.value.unidad,
                                decoration: const InputDecoration(hintText: 'Unidad'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: e.value.cantidad,
                                decoration: const InputDecoration(hintText: 'Cantidad'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: e.value.observaciones,
                                decoration: const InputDecoration(hintText: 'Observaciones'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  if (materiales.length > 1) {
                                    final row = materiales.removeAt(e.key);
                                    row.dispose();
                                  }
                                });
                              },
                            )
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => materiales.add(MaterialRowData())),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar material'),
                      ),
                    )
                  ],
                ),
              ),
              _seccionConTitulo(
                '6. Descripción del trabajo',
                TextField(
                  controller: descripcionTrabajo,
                  decoration: const InputDecoration(hintText: 'Describe el trabajo realizado'),
                  maxLines: 4,
                ),
              ),
              
              _seccionConTitulo(
                '7. Firmas',
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Técnico', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (firmaTecnico != null)
                            Column(
                              children: [
                                Image.memory(firmaTecnico!, height: 100),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: nombreTecnicoController,
                                  decoration: const InputDecoration(labelText: 'Nombre del técnico'),
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(() => firmaTecnico = null),
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text('Eliminar firma', style: TextStyle(color: Colors.red)),
                                )
                              ],
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => _tomarFirmas(esTecnico: true),
                              icon: const Icon(Icons.edit),
                              label: const Text('Firmar'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (firmaCliente != null)
                            Column(
                              children: [
                                Image.memory(firmaCliente!, height: 100),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: nombreClienteController,
                                  decoration: const InputDecoration(labelText: 'Nombre del cliente'),
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(() => firmaCliente = null),
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text('Eliminar firma', style: TextStyle(color: Colors.red)),
                                )
                              ],
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => _tomarFirmas(esTecnico: false),
                              icon: const Icon(Icons.edit),
                              label: const Text('Firmar'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Guardar como PDF'),
                  onPressed: () async {
                    final validation = _validar();
                    if (validation != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(validation)),
                      );
                      return;
                    }

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar generación de PDF'),
                        content: const Text('¿Deseas generar y enviar el PDF?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
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

                      // Validar que el PDF se generó correctamente
                      if (bytes.isEmpty) {
                        throw Exception('El PDF generado está vacío');
                      }

                      try {
                        await subirPdfAvances(
                          bytes,
                          folioParaPDF,
                          nombreCliente: clienteContratista.text,
                        );
                      } catch (e) {
                        // Error al subir, pero puede estar en cola
                        final errorMsg = e.toString();
                        if (mounted) {
                          Navigator.of(context).pop(); // Cerrar diálogo de progreso
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
                        Navigator.of(context).pop(); // Cerrar diálogo de progreso
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ PDF enviado exitosamente\nFolio: $folioParaPDF'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );

                      setState(() {
                        folioActual = folioParaPDF + 1;
                      });

                      await Printing.layoutPdf(
                        onLayout: (format) async => bytes,
                        name: 'Avance($folioParaPDF).pdf',
                      );
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop(); // Cerrar diálogo de progreso
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
              )
            ],
          ),
        ),
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
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
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

          // 1. Datos generales
          pw.Text('1. Datos generales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Proyecto/Obra: $proyectoObra'),
          pw.Text('Cliente/Contratista: $clienteContratista'),
          pw.SizedBox(height: 12),

          // 2. Obra
          pw.Text('2. Obra', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Descripción: $obraDescripcion'),
          pw.SizedBox(height: 4),
          pw.Text('Especificaciones técnicas: $obraEspecificaciones'),
          pw.SizedBox(height: 12),

          // 3. Avances
          pw.Text('3. Avances (fotos)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          buildFotoGrid('Inicio', fotosInicio),
          pw.SizedBox(height: 6),
          buildFotoGrid('Durante', fotosDurante),
          pw.SizedBox(height: 6),
          buildFotoGrid('Después', fotosDespues),
          pw.SizedBox(height: 12),

          // 4. Reporte del día
          pw.Text('4. Reporte del día', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Actividad realizada: $actividadRealizada'),
          pw.Text('Área/Nivel de obra: $areaNivelObra'),
          pw.SizedBox(height: 12),

          // 5. Resumen de materiales (tabla)
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

          // 6. Descripción del trabajo
          pw.Text('6. Descripción del trabajo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(descripcionTrabajo),
          pw.SizedBox(height: 12),

          // 7. Firmas
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
