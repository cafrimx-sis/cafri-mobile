import 'dart:io';

import 'package:cafri/helpers/local_pdf_storage.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

class PdfsGuardadosScreen extends StatefulWidget {
  const PdfsGuardadosScreen({super.key});

  @override
  State<PdfsGuardadosScreen> createState() => _PdfsGuardadosScreenState();
}

class _PdfsGuardadosScreenState extends State<PdfsGuardadosScreen> {
  late Future<List<File>> _pdfsFuture;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  void _loadPdfs() {
    _pdfsFuture = listarCopiasPdfLocales();
  }

  Future<void> _refresh() async {
    setState(_loadPdfs);
    await _pdfsFuture;
  }

  Future<void> _openPdf(File file) async {
    final result = await OpenFile.open(file.path);
    if (!mounted) return;

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deletePdf(File file) async {
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar PDF'),
        content: Text('Deseas eliminar "$name" del telefono?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (await file.exists()) {
        await file.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF eliminado del telefono')),
      );
      setState(_loadPdfs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _fileName(File file) {
    return file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<File>>(
          future: _pdfsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Center(child: Text('Error: ${snapshot.error}')),
                ],
              );
            }

            final pdfs = snapshot.data ?? [];
            if (pdfs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('No hay PDFs guardados en el telefono')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: pdfs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = pdfs[index];
                final stat = file.statSync();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE53935),
                      child: Icon(Icons.picture_as_pdf, color: Colors.white),
                    ),
                    title: Text(
                      _fileName(file),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_formatSize(stat.size)} - ${_formatDate(stat.modified)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _openPdf(file),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'open') {
                          _openPdf(file);
                        } else if (value == 'delete') {
                          _deletePdf(file);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'open',
                          child: Text('Abrir'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
