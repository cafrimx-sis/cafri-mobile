import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cafri/helpers/pdf_queue_service.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

Future<String> subirPdfTarea(
  Uint8List pdfBytes,
  int folio, {
  String? nombreCliente,
}) async {
  try {
    final queueService = PdfQueueService();

    // Validar que el PDF no esté vacío
    if (pdfBytes.isEmpty) {
      throw Exception('Error: El PDF generado está vacío');
    }

    _logger.i('[subirPdfTarea] Iniciando subida del PDF. Folio: $folio, Tamaño: ${pdfBytes.length} bytes');

    // Verificar conexión
    final hasConnection = await queueService.hasInternetConnection();

    if (!hasConnection) {
      _logger.w('[subirPdfTarea] Sin conexión. Guardando en cola local.');
      // Guardar en cola local
      await queueService.queuePdf(
        folio: folio,
        nombreCliente: nombreCliente ?? 'Sin nombre',
        pdfBytes: pdfBytes,
        tipo: 'Tarea',
      );
      throw Exception(
        'Sin conexión: PDF guardado en cola. Enviar cuando haya conexión.',
      );
    }

    // Enviar a Firebase con reintentos
    const maxReintentos = 3;
    int intentos = 0;
    String? downloadUrl;

    while (intentos < maxReintentos && downloadUrl == null) {
      try {
        intentos++;
        _logger.i('[subirPdfTarea] Intento $intentos/$maxReintentos de subida');

        // Agregamos un identificador único (Timestamp) para evitar colisiones
        // si dos usuarios suben el mismo folio al mismo tiempo.
        final uniqueId = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref('pdfs/tareas/Tarea_${folio}_$uniqueId.pdf');

        await ref.putData(
          pdfBytes,
          SettableMetadata(contentType: 'application/pdf'),
        );

        // Obtener URL de descarga para confirmar
        downloadUrl = await ref.getDownloadURL();
        _logger.i('[subirPdfTarea] PDF subido exitosamente. URL: $downloadUrl');

        // Verificar que el archivo existe en Firebase
        await ref.getMetadata();
        _logger.i('[subirPdfTarea] Archivo verificado en Firebase Storage');

      } catch (e) {
        _logger.e('[subirPdfTarea] Error en intento $intentos: $e');
        if (intentos < maxReintentos) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          // Guardar en cola si fallan todos los intentos
          _logger.w('[subirPdfTarea] Máximo de intentos alcanzado. Guardando en cola.');
          await queueService.queuePdf(
            folio: folio,
            nombreCliente: nombreCliente ?? 'Sin nombre',
            pdfBytes: pdfBytes,
            tipo: 'Tarea',
          );
          throw Exception(
            'Error subiendo PDF después de $maxReintentos intentos. PDF guardado en cola.',
          );
        }
      }
    }

    if (downloadUrl == null) {
      throw Exception('Error: No se pudo obtener la URL de descarga');
    }

    // Si se envió correctamente, eliminar de la cola si existe
    try {
      await queueService.removePdfFromQueue(folio);
      _logger.i('[subirPdfTarea] PDF eliminado de la cola');
    } catch (e) {
      _logger.w('[subirPdfTarea] Error eliminando de la cola: $e');
    }

    return downloadUrl;
  } on FirebaseException catch (e) {
    _logger.e('[subirPdfTarea] Error Firebase: ${e.code} - ${e.message}');
    throw Exception('Error Firebase: ${e.code} - ${e.message}');
  } catch (e) {
    _logger.e('[subirPdfTarea] Error general: $e');
    rethrow;
  }
}

Future<String> subirPdfAvances(
  Uint8List pdfBytes,
  int folio, {
  String? nombreCliente,
}) async {
  try {
    final queueService = PdfQueueService();

    // Validar que el PDF no esté vacío
    if (pdfBytes.isEmpty) {
      throw Exception('Error: El PDF generado está vacío');
    }

    _logger.i('[subirPdfAvances] Iniciando subida del PDF. Folio: $folio, Tamaño: ${pdfBytes.length} bytes');

    // Verificar conexión
    final hasConnection = await queueService.hasInternetConnection();

    if (!hasConnection) {
      _logger.w('[subirPdfAvances] Sin conexión. Guardando en cola local.');
      // Guardar en cola local
      await queueService.queuePdf(
        folio: folio,
        nombreCliente: nombreCliente ?? 'Sin nombre',
        pdfBytes: pdfBytes,
        tipo: 'Avance',
      );
      throw Exception(
        'Sin conexión: PDF guardado en cola. Enviar cuando haya conexión.',
      );
    }

    // Enviar a Firebase con reintentos
    const maxReintentos = 3;
    int intentos = 0;
    String? downloadUrl;

    while (intentos < maxReintentos && downloadUrl == null) {
      try {
        intentos++;
        _logger.i('[subirPdfAvances] Intento $intentos/$maxReintentos de subida');

        // Agregamos un identificador único (Timestamp) para evitar colisiones
        // si dos usuarios suben el mismo folio al mismo tiempo.
        final uniqueId = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref('pdfs/avances/Avance_${folio}_$uniqueId.pdf');

        await ref.putData(
          pdfBytes,
          SettableMetadata(contentType: 'application/pdf'),
        );

        // Obtener URL de descarga para confirmar
        downloadUrl = await ref.getDownloadURL();
        _logger.i('[subirPdfAvances] PDF subido exitosamente. URL: $downloadUrl');

        // Verificar que el archivo existe en Firebase
        await ref.getMetadata();
        _logger.i('[subirPdfAvances] Archivo verificado en Firebase Storage');

      } catch (e) {
        _logger.e('[subirPdfAvances] Error en intento $intentos: $e');
        if (intentos < maxReintentos) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          // Guardar en cola si fallan todos los intentos
          _logger.w('[subirPdfAvances] Máximo de intentos alcanzado. Guardando en cola.');
          await queueService.queuePdf(
            folio: folio,
            nombreCliente: nombreCliente ?? 'Sin nombre',
            pdfBytes: pdfBytes,
            tipo: 'Avance',
          );
          throw Exception(
            'Error subiendo PDF después de $maxReintentos intentos. PDF guardado en cola.',
          );
        }
      }
    }

    if (downloadUrl == null) {
      throw Exception('Error: No se pudo obtener la URL de descarga');
    }

    // Si se envió correctamente, eliminar de la cola si existe
    try {
      await queueService.removePdfFromQueue(folio, tipo: 'Avance');
      _logger.i('[subirPdfAvances] PDF eliminado de la cola');
    } catch (e) {
      _logger.w('[subirPdfAvances] Error eliminando de la cola: $e');
    }

    return downloadUrl;
  } on FirebaseException catch (e) {
    _logger.e('[subirPdfAvances] Error Firebase: ${e.code} - ${e.message}');
    throw Exception('Error Firebase: ${e.code} - ${e.message}');
  } catch (e) {
    _logger.e('[subirPdfAvances] Error general: $e');
    rethrow;
  }
}
