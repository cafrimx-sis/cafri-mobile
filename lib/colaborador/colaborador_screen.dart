// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cafri/autentificacion/auth_service.dart';
import 'package:cafri/autentificacion/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cafri/colaborador/calendarcolab_screen.dart';
import 'package:cafri/colaborador/pdf.dart';
import 'package:cafri/colaborador/ubicacion.dart';
import 'package:cafri/colaborador/actividades_screen.dart';
// import 'package:cafri/colaborador/historial_rutas.dart';
import 'package:cafri/colaborador/ruta.dart';
import 'package:cafri/colaborador/subidos.dart';

enum ColaboradorSection { actividades, calendario, documento, mapa, subidos }

/// Widget reutilizable para mostrar el Avatar/Fotografía del usuario (igual al AdminScreen)
class CustomUserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final double radius;
  final double fontSize;
  final Color? color;
  final GestureTapCallback? onTap;

  const CustomUserAvatar({
    super.key,
    this.photoUrl,
    this.displayName,
    this.radius = 30,
    this.fontSize = 25,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = color ?? Colors.indigo.withAlpha(217);

    Widget child;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      child = CircleAvatar(
        backgroundColor: Colors.white,
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    } else if (displayName != null && displayName!.isNotEmpty) {
      child = CircleAvatar(
        backgroundColor: bgColor,
        radius: radius,
        child: Text(
          displayName!.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      );
    } else {
      child = CircleAvatar(
        backgroundColor: Colors.grey[400],
        radius: radius,
        child: Icon(
          Icons.account_circle,
          color: Colors.white,
          size: fontSize * 1.1,
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: child);
  }
}

class ColaboradorScreen extends StatefulWidget {
  const ColaboradorScreen({super.key});

  @override
  State<ColaboradorScreen> createState() => _ColaboradorScreenState();
}

class _ColaboradorScreenState extends State<ColaboradorScreen> {
  late String userEmail;
  late String userId;

  // INICIO: NUEVO - Datos perfil
  String? photoUrl;
  String? nombre;
  String? rol;

  ColaboradorSection selectedSection = ColaboradorSection.actividades;
  final AuthService _authService = AuthService();
  final String googleMapsApiKey = 'AIzaSyDgJ6emXC-cKpFJ-CFhWiglhp0pq2xWf2c';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userEmail = user?.email ?? '';
    userId = user?.uid ?? '';
    if (user != null) {
      _loadUserInfo(user.uid);
    }
    _crearDocumentoInicialColaborador(userId: userId, email: userEmail).then((
      _,
    ) {
      SeguimientoTiempoRealService.start(userId, nombre: userEmail);
    });
  }

  Future<void> _loadUserInfo(String uid) async {
    // Cambia la colección a la que tú uses para los colaboradores
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        photoUrl = data['photoUrl'] as String?;
        nombre = data['name'] as String?;
        rol = data['rol'] as String?;
      });
    }
  }

  void _showFullProfilePhoto() {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      photoUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Padding(
                          padding: const EdgeInsets.all(60.0),
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                            padding: EdgeInsets.all(60.0),
                            child: Icon(
                              Icons.broken_image,
                              size: 70,
                              color: Colors.white70,
                            ),
                          ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 20,
                  right: 20,
                  child: Icon(Icons.close, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _crearDocumentoInicialColaborador({
    required String userId,
    required String email,
  }) async {
    if (userId.isEmpty) return;
    final docRef = FirebaseFirestore.instance
        .collection('ubicaciones_colaboradores')
        .doc(userId);

    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'email': email,
        'creado': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    SeguimientoTiempoRealService.stop();
    super.dispose();
  }

  void _handleDrawerSelection(ColaboradorSection section) async {
    Navigator.pop(context);
    setState(() {
      selectedSection = section;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.logout();
      await SeguimientoTiempoRealService.stop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildActividades() {
    return ColaboradorActividadesScreen();
  }

  Widget _buildCalendario() {
    return ColaboradorCalendario(userEmail: userEmail);
  }

  Widget _buildMapa() {
    return MapaConRutaDesdeUrl(apiKey: googleMapsApiKey);
  }

  Widget _buildProfileInfo(BuildContext context) {
    String displayName = nombre?.isNotEmpty == true ? nombre! : 'Usuario';
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomUserAvatar(
            photoUrl: photoUrl,
            displayName: nombre,
            radius: 20,
            fontSize: 17,
            onTap: _showFullProfilePhoto,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.6,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
            if (rol != null)
              Text(
                rol!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: _buildProfileInfo(
          context,
        ), // Nuevo: avatar y nombre (como Admin)
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app,
              color: Colors.redAccent,
              size: 28,
            ),
            tooltip: 'Salir',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Row(
                children: [
                  CustomUserAvatar(
                    photoUrl: photoUrl,
                    displayName: nombre,
                    radius: 28,
                    fontSize: 22,
                    onTap: _showFullProfilePhoto,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (nombre != null && nombre!.isNotEmpty)
                              ? nombre!
                              : 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rol != null)
                          Text(
                            rol!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        if (userEmail.isNotEmpty)
                          Text(
                            userEmail,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Actividades'),
              selected: selectedSection == ColaboradorSection.actividades,
              onTap: () =>
                  _handleDrawerSelection(ColaboradorSection.actividades),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calendario de actividades'),
              selected: selectedSection == ColaboradorSection.calendario,
              onTap: () =>
                  _handleDrawerSelection(ColaboradorSection.calendario),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Generar documento'),
              selected: selectedSection == ColaboradorSection.documento,
              onTap: () => _handleDrawerSelection(ColaboradorSection.documento),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('PDFs Pendientes'),
              selected: selectedSection == ColaboradorSection.subidos,
              onTap: () => _handleDrawerSelection(ColaboradorSection.subidos),
            ),
            // ListTile(
            //   leading: const Icon(Icons.map),
            //   title: const Text('Mapa con ruta desde URL'),
            //   selected: selectedSection == ColaboradorSection.mapa,
            //   onTap: () => _handleDrawerSelection(ColaboradorSection.mapa),
            // ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Salir', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          switch (selectedSection) {
            case ColaboradorSection.actividades:
              return _buildActividades();
            case ColaboradorSection.calendario:
              return _buildCalendario();
            case ColaboradorSection.documento:
              return const FormularioPDF();
            case ColaboradorSection.subidos:
              return const SubidosScreen();
            case ColaboradorSection.mapa:
              return _buildMapa();
          }
        },
      ),
    );
  }
}
