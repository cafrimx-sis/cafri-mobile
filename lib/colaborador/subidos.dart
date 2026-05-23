import 'package:flutter/material.dart';
import 'package:cafri/helpers/pdf_queue_service.dart';
import 'package:cafri/helpers/upload_pdf_storage.dart';
import 'package:cafri/colaborador/folio_service.dart';

class SubidosScreen extends StatefulWidget {
  const SubidosScreen({super.key});

  @override
  State<SubidosScreen> createState() => _SubidosScreenState();
}

class _SubidosScreenState extends State<SubidosScreen> {
  final PdfQueueService _queueService = PdfQueueService();
  late Future<List<PdfQueueItem>> _pendingPdfsFuture;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadPendingPdfs();
  }

  void _loadPendingPdfs() {
    _pendingPdfsFuture = _queueService.getPendingPdfs();
  }

  Future<void> _sendPdf(PdfQueueItem item) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Verificar conexión
      final hasConnection = await _queueService.hasInternetConnection();
      if (!hasConnection) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión. Intenta de nuevo.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _isSending = false;
        });
        return;
      }

      // Verificar si el folio local es menor que el folio actual en servidor
      // (puede ocurrir si otro dispositivo generó folios mientras este estaba offline)
      int folioAEnviar = item.folio;
      final lastFolioEnServidor = await FolioService.getLastFolio();
      if (item.folio < lastFolioEnServidor) {
        // El folio local quedó atrás, asignar uno nuevo
        folioAEnviar = await FolioService.getAndUpdateFolio();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Folio ${item.folio} quedó atrás. Reasignando a $folioAEnviar...',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Verificar si el folio ya fue procesado
      final yaFueProcesado = await FolioService.folioYaFueProcesado(
        folioAEnviar,
      );
      if (yaFueProcesado) {
        // Si ya existe un PDF con ese folio en servidor, NO eliminar sin más.
        // Obtenemos un folio nuevo de forma atómica y subimos con ese folio.
        final nuevoFolio = await FolioService.getAndUpdateFolio();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Folio $folioAEnviar ya existe. Reasignando a $nuevoFolio y subiendo...',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Intentar subir con nuevo folio
        if (item.tipo == 'Avance') {
          await subirPdfAvances(item.pdfBytes, nuevoFolio, nombreCliente: item.nombreCliente);
        } else {
          await subirPdfTarea(item.pdfBytes, nuevoFolio, nombreCliente: item.nombreCliente);
        }

        // Asegurar que el folio en la config no disminuya
        await FolioService.updateFolio(nuevoFolio);

        // Eliminar la copia local (la que tenía el folio antiguo)
        await _queueService.removePdfFromQueue(item.folio, tipo: item.tipo);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF enviado como ${item.tipo} $nuevoFolio'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Recargar la lista y salir
        _loadPendingPdfs();
        setState(() {
          _isSending = false;
        });
        return;
      }

      // Enviar PDF con folioAEnviar
      if (item.tipo == 'Avance') {
        await subirPdfAvances(item.pdfBytes, folioAEnviar, nombreCliente: item.nombreCliente);
      } else {
        await subirPdfTarea(item.pdfBytes, folioAEnviar, nombreCliente: item.nombreCliente);
      }

      // Actualizar folio de forma segura (atómica)
      await FolioService.updateFolio(folioAEnviar);

      // Eliminar de la cola
      await _queueService.removePdfFromQueue(item.folio, tipo: item.tipo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF ${item.tipo} $folioAEnviar enviado correctamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Recargar la lista
      _loadPendingPdfs();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendAllPdfs(List<PdfQueueItem> items) async {
    if (_isSending || items.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    int enviados = 0;
    int errores = 0;

    try {
      // Verificar conexión
      final hasConnection = await _queueService.hasInternetConnection();
      if (!hasConnection) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión. Intenta de nuevo.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _isSending = false;
        });
        return;
      }

      // Enviar todos los PDFs
      for (var item in items) {
        try {
          // Verificar si el folio local es menor que el folio actual en servidor
          int folioAEnviar = item.folio;
          final lastFolioEnServidor = await FolioService.getLastFolio();
          if (item.folio < lastFolioEnServidor) {
            // El folio local quedó atrás, asignar uno nuevo
            folioAEnviar = await FolioService.getAndUpdateFolio();
          }

          // Verificar si ya fue procesado
          final yaFueProcesado = await FolioService.folioYaFueProcesado(
            folioAEnviar,
          );
          if (yaFueProcesado) {
            // Reasignar folio de forma atómica y subir con el nuevo folio
            try {
              final nuevoFolio = await FolioService.getAndUpdateFolio();
              if (item.tipo == 'Avance') {
                await subirPdfAvances(item.pdfBytes, nuevoFolio, nombreCliente: item.nombreCliente);
              } else {
                await subirPdfTarea(item.pdfBytes, nuevoFolio, nombreCliente: item.nombreCliente);
              }
              await FolioService.updateFolio(nuevoFolio);
              await _queueService.removePdfFromQueue(item.folio, tipo: item.tipo);
              enviados++;
              continue;
            } catch (e) {
              errores++;
              continue;
            }
          }

          // Enviar PDF con folio ajustado
          if (item.tipo == 'Avance') {
            await subirPdfAvances(item.pdfBytes, folioAEnviar, nombreCliente: item.nombreCliente);
          } else {
            await subirPdfTarea(item.pdfBytes, folioAEnviar, nombreCliente: item.nombreCliente);
          }

          // Actualizar folio de forma segura
          await FolioService.updateFolio(folioAEnviar);

          // Eliminar de la cola
          await _queueService.removePdfFromQueue(item.folio, tipo: item.tipo);
          enviados++;
        } catch (e) {
          errores++;
        }
      }

      if (mounted) {
        String mensaje = 'Enviados: $enviados';
        if (errores > 0) {
          mensaje += ', Errores: $errores';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: errores == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Recargar la lista
      _loadPendingPdfs();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deletePdf(int folio, String tipo) async {
    try {
      await _queueService.removePdfFromQueue(folio, tipo: tipo);
      _loadPendingPdfs();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF eliminado'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDFs Pendientes de Envío'),
        backgroundColor: const Color(0xFF00A8E8),
        elevation: 0,
      ),
      body: FutureBuilder<List<PdfQueueItem>>(
        future: _pendingPdfsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay PDFs pendientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Todos los PDFs han sido enviados',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header con información
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${items.length} PDF(s) pendiente(s)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'En cola',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de PDFs
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                                size: 26,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.folio}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                      '${item.tipo} ${item.folio}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Folio guardado: ${item.folio}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Cliente: ${item.nombreCliente}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Guardado: ${item.fechaGuardado.toString().split('.')[0]}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Enviar'),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                                  () => _sendPdf(item),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Eliminar'),
                              onTap: () {
                                Future.delayed(
                                  Duration.zero,
                              () => _showDeleteConfirmation(item),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Botón para enviar todos
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : () => _sendAllPdfs(items),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8E8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Enviar todos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(PdfQueueItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar PDF'),
        content: Text('¿Estás seguro de que deseas eliminar ${item.tipo.toLowerCase()} ${item.folio}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePdf(item.folio, item.tipo);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
