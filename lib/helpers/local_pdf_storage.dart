import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> guardarCopiaPdfEnTelefono({
  required Uint8List pdfBytes,
  required String fileName,
  String folderName = 'CAFRI_PDFs',
}) async {
  if (pdfBytes.isEmpty) {
    throw Exception('El PDF esta vacio');
  }

  final targetDir = await getLocalPdfDirectory(folderName: folderName);

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  final safeName = _sanitizeFileName(fileName);
  final file = File('${targetDir.path}${Platform.pathSeparator}$safeName');
  await file.writeAsBytes(pdfBytes, flush: true);
  return file.path;
}

Future<Directory> getLocalPdfDirectory({
  String folderName = 'CAFRI_PDFs',
}) async {
  final baseDir = await _getBestStorageDir();
  return Directory('${baseDir.path}${Platform.pathSeparator}$folderName');
}

Future<List<File>> listarCopiasPdfLocales({
  String folderName = 'CAFRI_PDFs',
}) async {
  final dir = await getLocalPdfDirectory(folderName: folderName);
  if (!await dir.exists()) return [];

  final files = await dir
      .list()
      .where((entity) =>
          entity is File && entity.path.toLowerCase().endsWith('.pdf'))
      .cast<File>()
      .toList();

  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return files;
}

Future<Directory> _getBestStorageDir() async {
  try {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) return downloadsDir;
  } catch (_) {}

  try {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }
  } catch (_) {}

  return getApplicationDocumentsDirectory();
}

String _sanitizeFileName(String name) {
  final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (sanitized.isEmpty) return 'documento.pdf';
  return sanitized.toLowerCase().endsWith('.pdf') ? sanitized : '$sanitized.pdf';
}
