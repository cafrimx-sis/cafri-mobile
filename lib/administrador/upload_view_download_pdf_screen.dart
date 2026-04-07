// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Importante para Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfFileWithDate {
  final Reference ref;
  final DateTime? uploadDate;
  PdfFileWithDate({required this.ref, required this.uploadDate});
}

class PdfListScreen extends StatefulWidget {
  const PdfListScreen({super.key});

  @override
  State<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  late final Reference _pdfsRefTareas;
  late final Reference _pdfsRefAvances;
  List<PdfFileWithDate> _allFiles = [];
  List<PdfFileWithDate> _filteredFiles = [];
  bool _loading = true;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Selector de tipo de PDF
  String _selectedType = 'tareas'; // 'tareas' o 'avances'

  @override
  void initState() {
    super.initState();
    _pdfsRefTareas = FirebaseStorage.instance.ref('pdfs/tareas');
    _pdfsRefAvances = FirebaseStorage.instance.ref('pdfs/avances');
    _fetchFiles();
    _searchController.addListener(_filterFiles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFiles() async {
    setState(() => _loading = true);
    try {
      // Seleccionar la referencia según el tipo
      final pdfsRef = _selectedType == 'tareas' ? _pdfsRefTareas : _pdfsRefAvances;
      
      final result = await pdfsRef.listAll();
      List<PdfFileWithDate> filesWithDates = [];

      for (var ref in result.items) {
        try {
          final metadata = await ref.getMetadata();
          filesWithDates.add(
            PdfFileWithDate(ref: ref, uploadDate: metadata.timeCreated),
          );
        } catch (e) {
          filesWithDates.add(PdfFileWithDate(ref: ref, uploadDate: null));
        }
      }

      _allFiles = filesWithDates;
      _filterFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error cargando PDFs: $e")));
      }
      _allFiles = [];
      _filteredFiles = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterFiles() {
    setState(() {
      _search = _searchController.text.trim().toLowerCase();
      _filteredFiles = _allFiles.where((file) {
        return file.ref.name.toLowerCase().contains(_search);
      }).toList();
    });
  }

  void _refreshList() => _fetchFiles();

  Future<String> _getDownloadUrl(Reference ref) async {
    return await ref.getDownloadURL();
  }

  Future<void> _copyUrlToClipboard(Reference ref) async {
    try {
      final url = await _getDownloadUrl(ref);
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "¡Enlace copiado al portapapeles! Pegue en su navegador para descargar.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo copiar el enlace: $e")),
        );
      }
    }
  }

  Future<void> _verFormularioAvance(Reference ref, String fileName) async {
    setState(() => _loading = true);
    try {
      final folioMatch = RegExp(r'(\d+)').firstMatch(fileName);
      if (folioMatch == null) {
        throw Exception('No se pudo detectar el folio en el nombre del PDF.');
      }
      final folio = folioMatch.group(1)!;

      final doc = await FirebaseFirestore.instance
          .collection('avances')
          .doc('Avance_$folio')
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception('No se encontró el formulario de avances.');
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AvanceFormViewScreen(
            title: 'Avance $folio',
            data: doc.data()!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el formulario: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Abre siempre la URL del PDF en el navegador externo.
  Future<void> _launchDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    bool opened = false;
    try {
      if (await canLaunchUrl(uri)) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo abrir o descargar el PDF en el navegador."),
        ),
      );
    }
  }

  Future<bool?> _confirmDeleteDialog(String fileName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar borrado"),
        content: Text(
          "¿Seguro que deseas borrar el archivo \"$fileName\"? Esta acción es irreversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Borrar"),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePdf(Reference ref, String fileName) async {
    final confirmed = await _confirmDeleteDialog(fileName);
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ref.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Archivo \"$fileName\" borrado.")));
      await _fetchFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al borrar: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return "Fecha no disponible";
    return DateFormat('dd/MM/yyyy HH:mm', 'es').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista de PDFs subidos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _refreshList,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de tipo de PDF
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(label: Text("Tareas"), value: 'tareas'),
                ButtonSegment(label: Text("Avances"), value: 'avances'),
              ],
              selected: {_selectedType},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  _searchController.clear();
                  _fetchFiles();
                });
              },
            ),
          ),
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar por nombre",
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                ? const Center(child: Text("No hay PDFs para mostrar."))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFiles.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final pdfFile = _filteredFiles[index];
                      final ref = pdfFile.ref;
                      final fileName = ref.name;
                      final uploadDateStr = _formatDate(pdfFile.uploadDate);
                      return ListTile(
                        leading: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                        ),
                        title: Text(fileName),
                        subtitle: Text('Subido: $uploadDateStr'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (_selectedType == 'avances')
                              IconButton(
                                icon: const Icon(Icons.assignment_outlined),
                                tooltip: "Ver formulario de avances",
                                onPressed: () =>
                                    _verFormularioAvance(ref, fileName),
                              ),
                            IconButton(
                              icon: const Icon(Icons.content_copy),
                              tooltip: "Copiar enlace del PDF",
                              onPressed: () async {
                                await _copyUrlToClipboard(ref);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_rounded),
                              tooltip: "Descargar PDF",
                              onPressed: () async {
                                setState(() => _loading = true);
                                try {
                                  final url = await _getDownloadUrl(ref);
                                  if (!mounted) return;
                                  await _launchDownloadUrl(url);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("No se pudo descargar: $e"),
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: "Borrar PDF",
                              color: Colors.red,
                              onPressed: () => _deletePdf(ref, fileName),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AvanceFormViewScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const AvanceFormViewScreen({
    super.key,
    required this.title,
    required this.data,
  });

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4C81),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF111827)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _photoGrid(
    BuildContext context,
    String title,
    List<String> urls, {
    List<String>? thumbs,
  }) {
    if (urls.isEmpty) {
      return Text('$title: Sin fotos');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(urls.length, (index) {
            final fullUrl = urls[index];
            final thumbUrl =
                (thumbs != null && index < thumbs.length) ? thumbs[index] : fullUrl;
            return _RemoteImageTile(url: thumbUrl, fullUrl: fullUrl);
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final materiales = (data['materiales'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [];

    final fotosUrlsRaw = data['fotosUrls'] as Map?;
    final fotosUrls = {
      'inicio': (fotosUrlsRaw?['inicio'] as List?)?.whereType<String>().toList() ?? const [],
      'durante': (fotosUrlsRaw?['durante'] as List?)?.whereType<String>().toList() ?? const [],
      'despues': (fotosUrlsRaw?['despues'] as List?)?.whereType<String>().toList() ?? const [],
    };

    final fotosThumbUrlsRaw = data['fotosThumbUrls'] as Map?;
    final fotosThumbUrls = {
      'inicio': (fotosThumbUrlsRaw?['inicio'] as List?)?.whereType<String>().toList() ?? const [],
      'durante': (fotosThumbUrlsRaw?['durante'] as List?)?.whereType<String>().toList() ?? const [],
      'despues': (fotosThumbUrlsRaw?['despues'] as List?)?.whereType<String>().toList() ?? const [],
    };

    final firmasUrlsRaw = data['firmasUrls'] as Map?;
    final firmaTecnicoUrl = firmasUrlsRaw?['tecnico'] as String?;
    final firmaClienteUrl = firmasUrlsRaw?['cliente'] as String?;

    final firmasNombresRaw = (data['firmasNombres'] as Map?) ?? (data['firmas'] as Map?);
    final nombreTecnico = firmasNombresRaw?['tecnico'] as String? ?? '';
    final nombreCliente = firmasNombresRaw?['cliente'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'Datos generales',
              icon: Icons.assignment_ind_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Proyecto/Obra', data['proyectoObra']?.toString() ?? ''),
                  _infoRow('Cliente/Contratista', data['clienteContratista']?.toString() ?? ''),
                  _infoRow('Fecha', data['fechaFormateada']?.toString() ?? ''),
                ],
              ),
            ),
            _sectionCard(
              title: 'Obra',
              icon: Icons.construction_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Descripción', data['obraDescripcion']?.toString() ?? ''),
                  _infoRow('Especificaciones', data['obraEspecificaciones']?.toString() ?? ''),
                ],
              ),
            ),
            _sectionCard(
              title: 'Reporte del día',
              icon: Icons.event_note_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Actividad realizada', data['actividadRealizada']?.toString() ?? ''),
                  _infoRow('Área/Nivel de obra', data['areaNivelObra']?.toString() ?? ''),
                ],
              ),
            ),
            _sectionCard(
              title: 'Descripción del trabajo',
              icon: Icons.description_outlined,
              child: Text(data['descripcionTrabajo']?.toString() ?? ''),
            ),
            _sectionCard(
              title: 'Avances (fotos)',
              icon: Icons.photo_library_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _photoGrid(
                    context,
                    'Inicio',
                    fotosUrls['inicio'] ?? const [],
                    thumbs: fotosThumbUrls['inicio'],
                  ),
                  const SizedBox(height: 8),
                  _photoGrid(
                    context,
                    'Durante',
                    fotosUrls['durante'] ?? const [],
                    thumbs: fotosThumbUrls['durante'],
                  ),
                  const SizedBox(height: 8),
                  _photoGrid(
                    context,
                    'Después',
                    fotosUrls['despues'] ?? const [],
                    thumbs: fotosThumbUrls['despues'],
                  ),
                ],
              ),
            ),
            _sectionCard(
              title: 'Materiales',
              icon: Icons.inventory_2_outlined,
              child: materiales.isEmpty
                  ? const Text('Sin materiales')
                  : Column(
                      children: materiales.map((m) {
                        final material = m['material']?.toString() ?? '';
                        final unidad = m['unidad']?.toString() ?? '';
                        final cantidad = m['cantidad']?.toString() ?? '';
                        final obs = m['observaciones']?.toString() ?? '';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow('Material', material),
                              _infoRow('Unidad', unidad),
                              _infoRow('Cantidad', cantidad),
                              _infoRow('Observaciones', obs),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _sectionCard(
              title: 'Firmas',
              icon: Icons.draw_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Técnico',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (firmaTecnicoUrl != null)
                          _RemoteImageTile(
                            url: firmaTecnicoUrl,
                            size: 140,
                          ),
                        Text(nombreTecnico),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Cliente',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (firmaClienteUrl != null)
                          _RemoteImageTile(
                            url: firmaClienteUrl,
                            size: 140,
                          ),
                        Text(nombreCliente),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteImageTile extends StatefulWidget {
  final String url;
  final String? fullUrl;
  final double size;

  const _RemoteImageTile({
    required this.url,
    this.fullUrl,
    this.size = 90,
  });

  @override
  State<_RemoteImageTile> createState() => _RemoteImageTileState();
}

class _RemoteImageTileState extends State<_RemoteImageTile> {
  void _openPreview(BuildContext context) {
    final previewUrl = widget.fullUrl ?? widget.url;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(previewUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.fullUrl ?? widget.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPreview(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.url,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: widget.size,
              height: widget.size,
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return InkWell(
              onTap: _openInBrowser,
              child: Container(
                width: widget.size,
                height: widget.size,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF5B5B5)),
                ),
                child: Stack(
                  children: const [
                    Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.image, color: Colors.redAccent, size: 30),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.open_in_new, color: Colors.red, size: 18),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
