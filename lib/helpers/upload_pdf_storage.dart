import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cafri/helpers/pdf_queue_service.dart';

Future<String> subirPdfTarea(
  Uint8List pdfBytes,
  int folio, {
  String? nombreCliente,
}) async {
  try {
    final queueService = PdfQueueService();

    // Verificar conexión
    final hasConnection = await queueService.hasInternetConnection();

    if (!hasConnection) {
      // Guardar en cola local
      await queueService.queuePdf(
        folio: folio,
        nombreCliente: nombreCliente ?? 'Sin nombre',
        pdfBytes: pdfBytes,
      );
      throw Exception(
        'Sin conexión: PDF guardado en cola. Enviar cuando haya conexión.',
      );
    }

    // Enviar a Firebase
    final ref = FirebaseStorage.instance.ref('pdfs/tareas/Tarea_$folio.pdf');
    await ref.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final downloadUrl = await ref.getDownloadURL();

    // Si se envió correctamente, eliminar de la cola si existe
    await queueService.removePdfFromQueue(folio);

    return downloadUrl;
  } on FirebaseException catch (e) {
    throw Exception('Error subiendo PDF: ${e.code} - ${e.message}');
  }
}
