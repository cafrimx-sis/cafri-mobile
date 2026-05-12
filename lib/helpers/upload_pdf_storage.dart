import 'dart:async';
import 'dart:typed_data';

import 'package:cafri/helpers/pdf_queue_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

enum PdfSendStatus { uploaded, queued }

class PdfSendResult {
  final PdfSendStatus status;
  final String? downloadUrl;
  final String message;

  const PdfSendResult._(this.status, this.downloadUrl, this.message);

  const PdfSendResult.uploaded(String url)
      : this._(PdfSendStatus.uploaded, url, 'PDF subido correctamente');

  const PdfSendResult.queued(String message)
      : this._(PdfSendStatus.queued, null, message);
}

const _uploadTimeout = Duration(seconds: 25);
const _metadataTimeout = Duration(seconds: 10);
const _downloadUrlTimeout = Duration(seconds: 10);

bool _isPermissionError(FirebaseException e) {
  return e.code == 'unauthorized' ||
      e.code == 'unauthenticated' ||
      e.code == 'permission-denied';
}

Future<PdfSendResult> _queueAndReturn({
  required PdfQueueService queueService,
  required Uint8List pdfBytes,
  required int folio,
  required String nombreCliente,
  required String message,
}) async {
  await queueService.queuePdf(
    folio: folio,
    nombreCliente: nombreCliente,
    pdfBytes: pdfBytes,
  );
  return PdfSendResult.queued(message);
}

Future<PdfSendResult> subirPdfTarea(
  Uint8List pdfBytes,
  int folio, {
  String? nombreCliente,
}) async {
  final queueService = PdfQueueService();

  if (pdfBytes.isEmpty) {
    throw Exception('Error: El PDF generado está vacío');
  }

  final cliente = (nombreCliente == null || nombreCliente.trim().isEmpty)
      ? 'Sin nombre'
      : nombreCliente.trim();

  // Si no hay internet real, encola y listo.
  final hasConnection = await queueService.hasInternetConnection();
  if (!hasConnection) {
    _logger.w('[subirPdfTarea] Sin internet. Guardando en cola local.');
    return _queueAndReturn(
      queueService: queueService,
      pdfBytes: pdfBytes,
      folio: folio,
      nombreCliente: cliente,
      message: 'Sin conexión: PDF guardado en cola.',
    );
  }

  _logger.i(
    '[subirPdfTarea] Subiendo PDF. Folio: $folio, Tamaño: ${pdfBytes.length} bytes',
  );

  const maxReintentos = 3;
  int intentos = 0;
  String? downloadUrl;

  while (intentos < maxReintentos && downloadUrl == null) {
    intentos++;
    try {
      final ref = FirebaseStorage.instance.ref('pdfs/tareas/Tarea_$folio.pdf');
      await ref
          .putData(
            pdfBytes,
            SettableMetadata(contentType: 'application/pdf'),
          )
          .timeout(_uploadTimeout);

      downloadUrl = await ref.getDownloadURL().timeout(_downloadUrlTimeout);
      await ref.getMetadata().timeout(_metadataTimeout);
    } on TimeoutException {
      _logger.w('[subirPdfTarea] Timeout en intento $intentos.');
      if (intentos < maxReintentos) continue;
      return _queueAndReturn(
        queueService: queueService,
        pdfBytes: pdfBytes,
        folio: folio,
        nombreCliente: cliente,
        message: 'Tiempo de espera agotado: PDF guardado en cola.',
      );
    } on FirebaseException catch (e) {
      _logger.e('[subirPdfTarea] FirebaseException: ${e.code} ${e.message}');
      if (_isPermissionError(e)) rethrow;
      if (intentos < maxReintentos) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      return _queueAndReturn(
        queueService: queueService,
        pdfBytes: pdfBytes,
        folio: folio,
        nombreCliente: cliente,
        message: 'No se pudo subir: PDF guardado en cola.',
      );
    } catch (e) {
      _logger.e('[subirPdfTarea] Error en intento $intentos: $e');
      if (intentos < maxReintentos) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      return _queueAndReturn(
        queueService: queueService,
        pdfBytes: pdfBytes,
        folio: folio,
        nombreCliente: cliente,
        message: 'Error subiendo: PDF guardado en cola.',
      );
    }
  }

  if (downloadUrl == null) {
    return _queueAndReturn(
      queueService: queueService,
      pdfBytes: pdfBytes,
      folio: folio,
      nombreCliente: cliente,
      message: 'No se pudo confirmar la subida: PDF guardado en cola.',
    );
  }

  // Si se envió correctamente, limpiar cola si existía.
  try {
    await queueService.removePdfFromQueue(folio);
  } catch (e) {
    _logger.w('[subirPdfTarea] Error eliminando de cola: $e');
  }

  return PdfSendResult.uploaded(downloadUrl);
}

Future<PdfSendResult> subirPdfAvances(
  Uint8List pdfBytes,
  int folio, {
  String? nombreCliente,
}) async {
  final queueService = PdfQueueService();

  if (pdfBytes.isEmpty) {
    throw Exception('Error: El PDF generado está vacío');
  }

  final cliente = (nombreCliente == null || nombreCliente.trim().isEmpty)
      ? 'Sin nombre'
      : nombreCliente.trim();

  final hasConnection = await queueService.hasInternetConnection();
  if (!hasConnection) {
    _logger.w('[subirPdfAvances] Sin internet. Guardando en cola local.');
    return _queueAndReturn(
      queueService: queueService,
      pdfBytes: pdfBytes,
      folio: folio,
      nombreCliente: cliente,
      message: 'Sin conexión: PDF guardado en cola.',
    );
  }

  _logger.i(
    '[subirPdfAvances] Subiendo PDF. Folio: $folio, Tamaño: ${pdfBytes.length} bytes',
  );

  const maxReintentos = 3;
  int intentos = 0;
  String? downloadUrl;

  while (intentos < maxReintentos && downloadUrl == null) {
    intentos++;
    try {
      final ref =
          FirebaseStorage.instance.ref('pdfs/avances/Avance_$folio.pdf');
      await ref
          .putData(
            pdfBytes,
            SettableMetadata(contentType: 'application/pdf'),
          )
          .timeout(_uploadTimeout);

      downloadUrl = await ref.getDownloadURL().timeout(_downloadUrlTimeout);
      await ref.getMetadata().timeout(_metadataTimeout);
    } on TimeoutException {
      _logger.w('[subirPdfAvances] Timeout en intento $intentos.');
      if (intentos < maxReintentos) continue;
      return _queueAndReturn(
        queueService: queueService,
        pdfBytes: pdfBytes,
        folio: folio,
        nombreCliente: cliente,
        message: 'Tiempo de espera agotado: PDF guardado en cola.',
      );
    } on FirebaseException catch (e) {
      _logger.e('[subirPdfAvances] FirebaseException: ${e.code} ${e.message}');
      if (_isPermissionError(e)) rethrow;
      if (intentos < maxReintentos) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      return _queueAndReturn(
        queueService: queueService,
        pdfBytes: pdfBytes,
        folio: folio,
        nombreCliente: cliente,
        message: 'No se pudo subir: PDF guardado en cola.',
      );
    } catch (e) {
      _logger.e('[subirPdfAvances] Error en intento $intentos: $e');
      if (intentos < maxReintentos) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      return _queueAndReturn(
        queueService: queueService,
        pdfBytes: pdfBytes,
        folio: folio,
        nombreCliente: cliente,
        message: 'Error subiendo: PDF guardado en cola.',
      );
    }
  }

  if (downloadUrl == null) {
    return _queueAndReturn(
      queueService: queueService,
      pdfBytes: pdfBytes,
      folio: folio,
      nombreCliente: cliente,
      message: 'No se pudo confirmar la subida: PDF guardado en cola.',
    );
  }

  try {
    await queueService.removePdfFromQueue(folio);
  } catch (e) {
    _logger.w('[subirPdfAvances] Error eliminando de cola: $e');
  }

  return PdfSendResult.uploaded(downloadUrl);
}

Future<bool> existePdfTareaEnStorage(int folio) async {
  final ref = FirebaseStorage.instance.ref('pdfs/tareas/Tarea_$folio.pdf');
  try {
    await ref.getMetadata().timeout(_metadataTimeout);
    return true;
  } on TimeoutException {
    // No podemos confirmar; por seguridad asumimos que existe para evitar overwrite.
    return true;
  } on FirebaseException catch (e) {
    if (e.code == 'object-not-found') return false;
    rethrow;
  }
}

Future<bool> existePdfAvanceEnStorage(int folio) async {
  final ref = FirebaseStorage.instance.ref('pdfs/avances/Avance_$folio.pdf');
  try {
    await ref.getMetadata().timeout(_metadataTimeout);
    return true;
  } on TimeoutException {
    return true;
  } on FirebaseException catch (e) {
    if (e.code == 'object-not-found') return false;
    rethrow;
  }
}
