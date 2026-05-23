// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cafri/autentificacion/auth_service.dart';
import 'package:cafri/autentificacion/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cafri/colaborador/calendarcolab_screen.dart';
import 'package:cafri/colaborador/pdf.dart';
import 'package:cafri/colaborador/pdf_avances.dart';
import 'package:cafri/colaborador/ubicacion.dart';
import 'package:cafri/colaborador/actividades_screen.dart';
import 'package:cafri/colaborador/pdfs_guardados.dart';
import 'package:cafri/colaborador/ruta.dart';
import 'package:cafri/colaborador/subidos.dart';

enum ColaboradorSection {
  actividades,
  calendario,
  documento,
  avances,
  mapa,
  subidos,
  guardados,
}

/// Widget reutilizable para mostrar el Avatar/Fotografía del usuario
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
    final Color bgColor = color ?? const Color(0xFF0056B3);

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

  String? photoUrl;
  String? nombre;
  String? rol;

  ColaboradorSection selectedSection = ColaboradorSection.actividades;
  final AuthService _authService = AuthService();
  final String googleMapsApiKey = 'AIzaSyDgJ6emXC-cKpFJ-CFhWiglhp0pq2xWf2c';

  // Paleta de colores visuales homologada
  static const _colorHeader = Color(0xFF003366);
  static const _colorAccent = Color(0xFF0056B3);
  static const _colorBg = Color(0xFFF3F6FB);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userEmail = user?.email ?? '';
    userId = user?.uid ?? '';
    if (user != null) {
      _loadUserInfo(user.uid);
    }
    _crearDocumentoInicialColaborador(userId: userId, email: userEmail).then((_) {
      SeguimientoTiempoRealService.start(userId, nombre: userEmail);
    });
  }

  Future<void> _loadUserInfo(String uid) async {
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
                        return const Padding(
                          padding: EdgeInsets.all(60.0),
                          child: CircularProgressIndicator(color: _colorAccent),
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

  void _handleDrawerSelection(ColaboradorSection section) {
    Navigator.pop(context);
    setState(() {
      selectedSection = section;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold, color: _colorHeader)),
        content: const Text('¿Deseas cerrar sesión del sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildActividades() => const ColaboradorActividadesScreen();
  Widget _buildCalendario() => ColaboradorCalendario(userEmail: userEmail);
  Widget _buildMapa() => MapaConRutaDesdeUrl(apiKey: googleMapsApiKey);

  Widget _buildProfileInfo(BuildContext context) {
    String displayName = nombre?.isNotEmpty == true ? nombre! : 'Usuario';
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomUserAvatar(
            photoUrl: photoUrl,
            displayName: nombre,
            radius: 18,
            fontSize: 15,
            onTap: _showFullProfilePhoto,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (rol != null)
                Text(
                  rol!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required ColaboradorSection section,
  }) {
    final isSelected = selectedSection == section;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? _colorAccent.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? _colorAccent : Colors.grey.shade600,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? _colorAccent : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        onTap: () => _handleDrawerSelection(section),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorBg,
      appBar: AppBar(
        backgroundColor: _colorHeader,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _buildProfileInfo(context),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.exit_to_app,
              color: Colors.white70,
              size: 24,
            ),
            tooltip: 'Salir',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(color: _colorHeader),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.0),
                    ),
                    child: CustomUserAvatar(
                      photoUrl: photoUrl,
                      displayName: nombre,
                      radius: 26,
                      fontSize: 20,
                      onTap: _showFullProfilePhoto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (nombre != null && nombre!.isNotEmpty) ? nombre! : 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rol != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            rol!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.check_circle_outline,
                    title: 'Actividades',
                    section: ColaboradorSection.actividades,
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'Calendario de actividades',
                    section: ColaboradorSection.calendario,
                  ),
                  _buildDrawerItem(
                    icon: Icons.description,
                    title: 'Generar documento',
                    section: ColaboradorSection.documento,
                  ),
                  _buildDrawerItem(
                    icon: Icons.trending_up,
                    title: 'Reporte de Avances',
                    section: ColaboradorSection.avances,
                  ),
                  _buildDrawerItem(
                    icon: Icons.file_upload,
                    title: 'PDFs Pendientes',
                    section: ColaboradorSection.subidos,
                  ),
                  _buildDrawerItem(
                    icon: Icons.folder_copy_outlined,
                    title: 'PDFs Guardados',
                    section: ColaboradorSection.guardados,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 22),
              title: const Text(
                'Salir',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onTap: _logout,
            ),
            const SizedBox(height: 12),
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
            case ColaboradorSection.avances:
              return const FormularioAvancesPDF();
            case ColaboradorSection.subidos:
              return const SubidosScreen();
            case ColaboradorSection.guardados:
              return const PdfsGuardadosScreen();
            case ColaboradorSection.mapa:
              return _buildMapa();
          }
        },
      ),
    );
  }
}