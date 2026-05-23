import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:convert';

class PdfQueueItem {
  final int folio;
  final String nombreCliente;
  final Uint8List pdfBytes;
  final DateTime fechaGuardado;
  final String fileName;
  final String tipo;

  PdfQueueItem({
    required this.folio,
    required this.nombreCliente,
    required this.pdfBytes,
    required this.fechaGuardado,
    required this.fileName,
    this.tipo = 'Tarea',
  });

  Map<String, dynamic> toJson() => {
    'folio': folio,
    'nombreCliente': nombreCliente,
    'fechaGuardado': fechaGuardado.toIso8601String(),
    'fileName': fileName,
    'tipo': tipo,
  };

  static PdfQueueItem fromJson(Map<String, dynamic> json, Uint8List pdfBytes) =>
      PdfQueueItem(
        folio: json['folio'],
        nombreCliente: json['nombreCliente'],
        pdfBytes: pdfBytes,
        fechaGuardado: DateTime.parse(json['fechaGuardado']),
        fileName: json['fileName'],
        tipo: json['tipo'] ?? 'Tarea',
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
    String tipo = 'Tarea',
  }) async {
    try {
      final queueDir = await _getPdfQueueDir();
      final fileName = '${tipo}_$folio.pdf';
      final filePath = '${queueDir.path}/$fileName';

      // Guardar el archivo PDF
      await File(filePath).writeAsBytes(pdfBytes);

      // Guardar metadata en JSON
      final metadataFile = File('${queueDir.path}/queue_metadata.json');
      List<dynamic> metadata = [];

      if (await metadataFile.exists()) {
        try {
          final content = await metadataFile.readAsString();
          metadata = jsonDecode(content);
        } catch (e) {
          // Si el JSON está corrupto, empezamos limpio
          metadata = [];
        }
      }

      // Deduplicar antes de agregar
      metadata.removeWhere((item) => item['fileName'] == fileName);

      metadata.add({
        'folio': folio,
        'nombreCliente': nombreCliente,
        'fechaGuardado': DateTime.now().toIso8601String(),
        'fileName': fileName,
        'tipo': tipo,
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

      List<dynamic> metadata = [];
      try {
        final content = await metadataFile.readAsString();
        metadata = jsonDecode(content);
      } catch (e) {
        // En caso de JSON corrupto, devolver lista vacía en lugar de fallar
        return [];
      }

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
  Future<void> removePdfFromQueue(int folio, {String tipo = 'Tarea'}) async {
    try {
      final queueDir = await _getPdfQueueDir();
      final fileName = '${tipo}_$folio.pdf';
      final filePath = '${queueDir.path}/$fileName';

      // Eliminar archivo PDF
      if (await File(filePath).exists()) {
        await File(filePath).delete();
      }

      // Actualizar metadata
      final metadataFile = File('${queueDir.path}/queue_metadata.json');
      if (await metadataFile.exists()) {
        try {
          final content = await metadataFile.readAsString();
          List<dynamic> metadata = jsonDecode(content);
          metadata.removeWhere((item) => item['fileName'] == fileName);
          await metadataFile.writeAsString(jsonEncode(metadata));
        } catch (e) {
          // Ignorar si no se puede leer el metadata al intentar eliminar
        }
      }
    } catch (e) {
      throw Exception('Error eliminando PDF de la cola: $e');
    }
  }

  /// Verifica si hay conexión a internet
  Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
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
