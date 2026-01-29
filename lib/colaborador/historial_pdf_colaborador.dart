import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class HistorialPdfColaborador extends StatefulWidget {
  const HistorialPdfColaborador({super.key});

  @override
  State<HistorialPdfColaborador> createState() => _HistorialPdfColaboradorState();
}

class _HistorialPdfColaboradorState extends State<HistorialPdfColaborador> {
  late final Reference _pdfsRefTareas;
  late final Reference _pdfsRefAvances;
  String _selectedType = 'tareas'; // 'tareas' o 'avances'
  List<PdfFileWithDate> _allFiles = [];
  List<PdfFileWithDate> _filteredFiles = [];
  bool _loading = false;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

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

      // Ordenar por fecha descendente (más recientes primero)
      filesWithDates.sort((a, b) {
        final dateA = a.uploadDate ?? DateTime.fromMicrosecondsSinceEpoch(0);
        final dateB = b.uploadDate ?? DateTime.fromMicrosecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      _allFiles = filesWithDates;
      _filterFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando PDFs: $e')),
        );
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

  String _formatDate(DateTime? d) {
    if (d == null) return 'Fecha no disponible';
    return DateFormat('dd/MM/yyyy HH:mm', 'es').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de PDFs'),
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
          // Selector de tipo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(label: Text('Tareas'), value: 'tareas'),
                ButtonSegment(label: Text('Avances'), value: 'avances'),
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
                labelText: 'Buscar por nombre',
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
          // Lista de PDFs
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                    ? const Center(child: Text('No hay PDFs para mostrar.'))
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
                            trailing: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
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

class PdfFileWithDate {
  final Reference ref;
  final DateTime? uploadDate;

  PdfFileWithDate({required this.ref, this.uploadDate});
}
