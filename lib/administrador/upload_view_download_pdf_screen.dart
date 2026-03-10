// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Importante para Clipboard

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
