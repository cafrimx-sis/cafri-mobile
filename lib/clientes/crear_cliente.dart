import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ignore_for_file: use_build_context_synchronously

class ClienteCreateScreen extends StatefulWidget {
  const ClienteCreateScreen({super.key});

  @override
  State<ClienteCreateScreen> createState() => _ClienteCreateScreenState();
}

class _ClienteCreateScreenState extends State<ClienteCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controles comunes
  final _codigoController = TextEditingController();
  final _telefonoController = TextEditingController();

  // Persona
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _correoController = TextEditingController();

  // Empresa
  final _empresaNombreController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _rfcController = TextEditingController();

  String _tipoCliente = 'persona'; // 'persona' | 'empresa'

  bool _isLoading = false;
  bool _isLoadingCodigo = true;

  @override
  void initState() {
    super.initState();
    _generarCodigoCliente();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _telefonoController.dispose();

    _nombreController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _correoController.dispose();

    _empresaNombreController.dispose();
    _razonSocialController.dispose();
    _rfcController.dispose();

    super.dispose();
  }

  Future<void> _generarCodigoCliente() async {
    try {
      // Busca el último código generado en la colección
      final snapshot = await FirebaseFirestore.instance
          .collection('clientes')
          .orderBy('codigo', descending: true)
          .limit(1)
          .get();

      String nuevoCodigo;
      if (snapshot.docs.isNotEmpty) {
        final ultimoCodigo = snapshot.docs.first['codigo'] ?? '';
        // Extrae el número del código (ej: CLI001 -> 1)
        final match = RegExp(r'^CLI(\d+)$').firstMatch(ultimoCodigo);
        int siguiente = 1;
        if (match != null) {
          siguiente = int.parse(match.group(1)!) + 1;
        }
        nuevoCodigo = 'CLI${siguiente.toString().padLeft(3, '0')}';
      } else {
        nuevoCodigo = 'CLI001';
      }
      _codigoController.text = nuevoCodigo;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCodigo = false;
        });
      }
    }
  }

  // Validaciones
  String? _validateNotEmpty(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label es obligatorio';
    return null;
  }

  String? _validateTelefono(String? value) {
    if (value == null || value.trim().isEmpty) return 'Teléfono es obligatorio';
    if (!RegExp(r'^\d{7,}$').hasMatch(value.trim())) return 'Teléfono inválido';
    return null;
  }

  String? _validateCorreo(String? value) {
    if (value == null || value.trim().isEmpty) return 'Correo es obligatorio';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) return 'Correo inválido';
    return null;
  }

  // RFC (México) típico: 12 o 13 caracteres alfanuméricos con patrón
  // Permitimos validación flexible: obligatorio no vacío y alfanumérico de 12-13.
  String? _validateRFC(String? value) {
    if (value == null || value.trim().isEmpty) return 'RFC es obligatorio';
    final v = value.trim().toUpperCase();
    if (!RegExp(r'^[A-ZÑ&0-9]{12,13}$').hasMatch(v)) return 'RFC inválido';
    return null;
  }

  Future<void> _registrarCliente() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final base = <String, dynamic>{
        'codigo': _codigoController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'tipo': _tipoCliente, // 'persona' | 'empresa'
        'createdAt': FieldValue.serverTimestamp(),
      };

      Map<String, dynamic> data;

      if (_tipoCliente == 'empresa') {
        // Para empresa, se guardan los campos solicitados:
        // nombre de la empresa (como 'nombre' para compatibilidad),
        // razón social, rfc y teléfono.
        data = {
          ...base,
          'nombre': _empresaNombreController.text.trim(),
          'razon_social': _razonSocialController.text.trim(),
          'rfc': _rfcController.text.trim().toUpperCase(),
        };
      } else {
        // Persona: se mantienen los campos originales.
        data = {
          ...base,
          'nombre': _nombreController.text.trim(),
          'direccion': _direccionController.text.trim(),
          'ciudad': _ciudadController.text.trim(),
          'correo': _correoController.text.trim(),
        };
      }

      final docRef = await FirebaseFirestore.instance
          .collection('clientes')
          .add(data);

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Cliente registrado exitosamente! ID: ${docRef.id}'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al registrar cliente: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpresa = _tipoCliente == 'empresa';

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Cliente')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Tipo de cliente
                    DropdownButtonFormField<String>(
                      initialValue: _tipoCliente,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de cliente',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'persona',
                          child: Text('Persona'),
                        ),
                        DropdownMenuItem(
                          value: 'empresa',
                          child: Text('Empresa'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _tipoCliente = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Código autogenerado, solo lectura
                    TextFormField(
                      controller: _codigoController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Código de Cliente',
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingCodigo)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),

                    // Sección condicional según tipo
                    if (isEmpresa) ...[
                      TextFormField(
                        controller: _empresaNombreController,
                        validator: (v) =>
                            _validateNotEmpty(v, 'Nombre de la empresa'),
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la empresa',
                          prefixIcon: Icon(Icons.apartment_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _razonSocialController,
                        validator: (v) => _validateNotEmpty(v, 'Razón social'),
                        decoration: const InputDecoration(
                          labelText: 'Razón social',
                          prefixIcon: Icon(Icons.business_center_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _rfcController,
                        validator: _validateRFC,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'RFC',
                          prefixIcon: Icon(Icons.assignment_ind_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefonoController,
                        validator: _validateTelefono,
                        decoration: const InputDecoration(
                          labelText: 'Número de teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _nombreController,
                        validator: (v) => _validateNotEmpty(v, 'Nombre'),
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _direccionController,
                        validator: (v) => _validateNotEmpty(v, 'Dirección'),
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ciudadController,
                        validator: (v) => _validateNotEmpty(v, 'Ciudad'),
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefonoController,
                        validator: _validateTelefono,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _correoController,
                        validator: _validateCorreo,
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],

                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _isLoadingCodigo
                                ? null
                                : _registrarCliente,
                            child: const Text('Registrar Cliente'),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
