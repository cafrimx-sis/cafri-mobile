import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class PdfQueueItem {
  final int folio;
  final String nombreCliente;
  final Uint8List pdfBytes;
  final DateTime fechaGuardado;
  final String fileName;

  PdfQueueItem({
    required this.folio,
    required this.nombreCliente,
    required this.pdfBytes,
    required this.fechaGuardado,
    required this.fileName,
  });

  Map<String, dynamic> toJson() => {
    'folio': folio,
    'nombreCliente': nombreCliente,
    'fechaGuardado': fechaGuardado.toIso8601String(),
    'fileName': fileName,
  };

  static PdfQueueItem fromJson(Map<String, dynamic> json, Uint8List pdfBytes) =>
      PdfQueueItem(
        folio: json['folio'],
        nombreCliente: json['nombreCliente'],
        pdfBytes: pdfBytes,
        fechaGuardado: DateTime.parse(json['fechaGuardado']),
        fileName: json['fileName'],
      );
}

class PdfQueueService {
  static final PdfQueueService _instance = PdfQueueService._internal();

  factory PdfQueueService() {
    return _instance;
  }

  PdfQueueService._internal();

  Future<Directory> _getPdfQueueDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final queueDir = Directory('${dir.path}/pdf_queue');
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }
    return queueDir;
  }

  /// Guarda un PDF en la cola local
  Future<void> queuePdf({
    required int folio,
    required String nombreCliente,
    required Uint8List pdfBytes,
  }) async {
    try {
      final queueDir = await _getPdfQueueDir();
      final fileName = 'Tarea_$folio.pdf';
      final filePath = '${queueDir.path}/$fileName';

      // Guardar el archivo PDF
      await File(filePath).writeAsBytes(pdfBytes);

      // Guardar metadata en JSON
      final metadataFile = File('${queueDir.path}/queue_metadata.json');
      List<dynamic> metadata = [];

      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        metadata = jsonDecode(content);
      }

      metadata.add({
        'folio': folio,
        'nombreCliente': nombreCliente,
        'fechaGuardado': DateTime.now().toIso8601String(),
        'fileName': fileName,
      });

      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      throw Exception('Error guardando PDF en cola: $e');
    }
  }

  /// Obtiene todos los PDFs en la cola
  Future<List<PdfQueueItem>> getPendingPdfs() async {
    try {
      final queueDir = await _getPdfQueueDir();
      final metadataFile = File('${queueDir.path}/queue_metadata.json');

      if (!await metadataFile.exists()) {
        return [];
      }

      final content = await metadataFile.readAsString();
      final List<dynamic> metadata = jsonDecode(content);

      List<PdfQueueItem> items = [];
      for (var item in metadata) {
        final filePath = '${queueDir.path}/${item['fileName']}';
        if (await File(filePath).exists()) {
          final pdfBytes = await File(filePath).readAsBytes();
          items.add(PdfQueueItem.fromJson(item, pdfBytes));
        }
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  /// Elimina un PDF de la cola después de ser enviado
  Future<void> removePdfFromQueue(int folio) async {
    try {
      final queueDir = await _getPdfQueueDir();
      final fileName = 'Tarea_$folio.pdf';
      final filePath = '${queueDir.path}/$fileName';

      // Eliminar archivo PDF
      if (await File(filePath).exists()) {
        await File(filePath).delete();
      }

      // Actualizar metadata
      final metadataFile = File('${queueDir.path}/queue_metadata.json');
      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        List<dynamic> metadata = jsonDecode(content);
        metadata.removeWhere((item) => item['fileName'] == fileName);
        await metadataFile.writeAsString(jsonEncode(metadata));
      }
    } catch (e) {
      throw Exception('Error eliminando PDF de la cola: $e');
    }
  }

  /// Verifica si hay conexión a internet
  Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    // Wi‑Fi/datos no siempre significa "internet". Verificación rápida con DNS.
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Limpia toda la cola
  Future<void> clearQueue() async {
    try {
      final queueDir = await _getPdfQueueDir();
      if (await queueDir.exists()) {
        await queueDir.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('Error limpiando la cola: $e');
    }
  }
}
