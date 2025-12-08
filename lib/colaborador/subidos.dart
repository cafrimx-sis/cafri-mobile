import 'package:flutter/material.dart';
import 'package:cafri/helpers/pdf_queue_service.dart';
import 'package:cafri/helpers/upload_pdf_storage.dart';

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

      // Enviar PDF
      await subirPdfTarea(item.pdfBytes, item.folio);

      // Eliminar de la cola
      await _queueService.removePdfFromQueue(item.folio);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Tarea ${item.folio} enviado correctamente'),
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
          await subirPdfTarea(item.pdfBytes, item.folio);
          await _queueService.removePdfFromQueue(item.folio);
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

  Future<void> _deletePdf(int folio) async {
    try {
      await _queueService.removePdfFromQueue(folio);
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
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red[700],
                          ),
                        ),
                        title: Text(
                          'Tarea ${item.folio}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  () => _showDeleteConfirmation(item.folio),
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

  void _showDeleteConfirmation(int folio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar PDF'),
        content: Text('¿Estás seguro de que deseas eliminar la tarea $folio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePdf(folio);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
