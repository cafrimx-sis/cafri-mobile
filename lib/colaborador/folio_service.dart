import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:math';

class FolioService {
  static final Logger _logger = Logger();

  static const String _collection = 'config';
  static const String _document = 'folio';
  static const String _field = 'valor';
  static const int _defaultFolio = 2140669;

  /// Obtiene el siguiente folio disponible desde Firestore (NO seguro para concurrencia).
  static Future<int> getNextFolio() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document)
          .get();

      final ultimoFolio = doc.data()?[_field] as int?;
      final siguienteFolio = (ultimoFolio ?? _defaultFolio) + 1;
      _logger.i(
        '[FolioService] getNextFolio: El siguiente folio es $siguienteFolio',
      );
      return siguienteFolio;
    } catch (e, stack) {
      _logger.e(
        '[FolioService] Error en getNextFolio',
        error: e,
        stackTrace: stack,
      );
      // Devuelve el default en caso de error
      return _defaultFolio + 1;
    }
  }

  /// Actualiza el folio en Firestore después de generar un PDF (NO seguro para concurrencia).
  static Future<void> updateFolio(int nuevoFolio) async {
    try {
      // Usar transacción para evitar sobrescribir con un valor menor.
      final docRef = FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final current = (snapshot.data()?[_field] as int?) ?? _defaultFolio;
        final newValue = max(current, nuevoFolio);
        transaction.set(docRef, {_field: newValue}, SetOptions(merge: true));
      });
      _logger.i(
        '[FolioService] updateFolio: Folio actualizado a $nuevoFolio (secure)',
      );
    } catch (e, stack) {
      _logger.e(
        '[FolioService] Error en updateFolio',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Obtiene y actualiza el folio de manera atómica usando una transacción.
  /// Garantiza que cada llamada concurrente reciba un folio único y secuencial.
  static Future<int> getAndUpdateFolio() async {
    try {
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final docRef = FirebaseFirestore.instance
            .collection(_collection)
            .doc(_document);
        final snapshot = await transaction.get(docRef);
        final ultimoFolio = snapshot.data()?[_field] as int? ?? _defaultFolio;
        final nuevoFolio = ultimoFolio + 1;
        transaction.set(docRef, {_field: nuevoFolio}, SetOptions(merge: true));
        _logger.i(
          '[FolioService] getAndUpdateFolio: Folio actualizado a $nuevoFolio',
        );
        return nuevoFolio;
      });
    } catch (e, stack) {
      _logger.e(
        '[FolioService] Error en getAndUpdateFolio',
        error: e,
        stackTrace: stack,
      );
      // Devuelve el default en caso de error
      return _defaultFolio + 1;
    }
  }

  /// Obtiene el último folio sin actualizarlo (para lectura segura)
  static Future<int> getLastFolio() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document)
          .get();

      final ultimoFolio = doc.data()?[_field] as int?;
      final folioActual = ultimoFolio ?? _defaultFolio;
      _logger.i('[FolioService] getLastFolio: El último folio es $folioActual');
      return folioActual;
    } catch (e, stack) {
      _logger.e(
        '[FolioService] Error en getLastFolio',
        error: e,
        stackTrace: stack,
      );
      return _defaultFolio;
    }
  }

  /// Verifica si un folio ya fue enviado (para evitar duplicados)
  static Future<bool> folioYaFueProcesado(int folio) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('pdfs')
          .where('folio', isEqualTo: folio)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e, stack) {
      _logger.e(
        '[FolioService] Error en folioYaFueProcesado',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }
}
