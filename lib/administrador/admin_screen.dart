// ignore_for_file: use_build_context_synchronously

import 'package:cafri/administrador/upload_view_download_pdf_screen.dart';
import 'package:cafri/colaborador/pdf.dart';
import 'package:flutter/material.dart';
import 'package:cafri/autentificacion/auth_service.dart';
import 'package:cafri/autentificacion/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cafri/administrador/user_crud_screens.dart';
import 'package:cafri/clientes/ver_cliente.dart';
import 'package:cafri/catalogo_servicios/ver_cat_servicio_screen.dart';
import 'package:cafri/administrador/cotizacion/cotizacion_screen.dart';
import 'package:cafri/administrador/cotizacion/cotizaciones_listar_screen.dart';
import 'package:cafri/administrador/calendaradmin_screen.dart';
import 'package:cafri/administrador/historial_screen.dart';
import 'package:cafri/administrador/calendarioacti_screen.dart';
import 'package:cafri/administrador/geolo.dart';
import 'package:cafri/administrador/dashboard_metricas.dart';

/// CustomUserAvatar: Muestra avatar, inicial o icono generico.
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

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String userEmail = '';
  String? photoUrl;
  String? nombre;
  String? rol;
  String? phone;
  String? department;
  String? position;
  final AuthService _authService = AuthService();

  Widget? _mainContentWidget;
  late final List<_MenuGroup> _menuGroups;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userEmail = user?.email ?? '';
    if (user != null) {
      _loadUserInfo(user.uid);
    }
    _mainContentWidget = _buildMainContent();
    _menuGroups = [
      _MenuGroup('Usuarios', Icons.people, [
        _MenuOption('Usuarios', Icons.people, const UserListScreen()),
        _MenuOption('Clientes', Icons.people_alt, const ClientesListarScreen()),
      ]),
      _MenuGroup('Servicios', Icons.miscellaneous_services, [
        _MenuOption(
          'Servicios',
          Icons.miscellaneous_services,
          const ListarServiciosScreen(),
        ),
        _MenuOption(
          'Generar Cotización',
          Icons.people_alt,
          const CotizacionScreen(),
        ),
        _MenuOption(
          'Descargar Cotizaciones',
          Icons.list_alt,
          const HistorialCotizacionesScreen(),
        ),
      ]),
      _MenuGroup('Agenda', Icons.event, [
        _MenuOption('Agendar', Icons.event, const CalendarPage()),
        _MenuOption(
          'Calendario',
          Icons.calendar_month,
          const CalendarAdminScreen(),
        ),
      ]),
      _MenuGroup('Actividades', Icons.history, [
        _MenuOption(
          'Historial de Actividades',
          Icons.history,
          const HistorialActividadesScreen(),
        ),
        _MenuOption(
          'Seguir',
          Icons.spatial_tracking,
          const MonitoreoTiempoRealAdmin(),
        ),
      ]),
      _MenuGroup('Reportes', Icons.bar_chart, [
        _MenuOption(
          'Métricas',
          Icons.bar_chart,
          DashboardMetricasActividadesConFiltro(),
        ),
        _MenuOption(
          'ver y descargar PDF',
          Icons.picture_as_pdf,
          PdfListScreen(),
        ),
        _MenuOption(
          'generar y subir PDF',
          Icons.picture_as_pdf,
          FormularioPDF(),
        ),
      ]),
    ];
  }

  Future<void> _loadUserInfo(String uid) async {
    // Asegúrate de que la colección sea correcta ("usuarios" o "users" según tu colección real)
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
        phone = data['phone'] as String?;
        department = data['department'] as String?;
        position = data['position'] as String?;
      });
    }
  }

  void _handleMenuSelection(_MenuOption option) {
    setState(() {
      _mainContentWidget = option.screen;
    });
    Navigator.of(context).maybePop();
  }

  void _goHome() {
    setState(() {
      _mainContentWidget = _buildMainContent();
    });
    Navigator.of(context).maybePop();
  }

  Future<void> _handleLogout() async {
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
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
                    //color: Colors.black.withOpacity(0.7),
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

  Widget _buildMainContent() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 29, 77, 235),
            Color.fromARGB(255, 0, 0, 0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Card(
          elevation: 12,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.indigo.withAlpha(220),
                        Colors.blue.withAlpha(180),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '¡Bienvenido, Administrador!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Gestiona clientes, agenda y más desde este panel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Divider(
                  color: Colors.indigo.withAlpha(80),
                  thickness: 1.2,
                  indent: 30,
                  endIndent: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  userEmail,
                  style: const TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --- ACTUALIZACIÓN AQUÍ ---
  Widget _buildProfileInfo() {
    String displayName = nombre?.isNotEmpty == true ? nombre! : 'users';

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.8),
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
            radius: 22,
            fontSize: 18,
            onTap: _showFullProfilePhoto,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerMenu() {
    return Drawer(
      backgroundColor: Colors.grey[50],
      child: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 22,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff1d4deb), Color(0xFF374BBB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: CustomUserAvatar(
                      photoUrl: photoUrl,
                      displayName: nombre,
                      radius: 30,
                      fontSize: 26,
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
              leading: const Icon(Icons.home, color: Colors.indigo),
              title: const Text(
                "Inicio",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: _goHome,
            ),
            ..._menuGroups.map(
              (group) => Column(
                children: [
                  ExpansionTile(
                    leading: Icon(group.icon, color: Colors.indigo),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text(
                      group.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    children: group.options
                        .map(
                          (option) => ListTile(
                            leading: Icon(
                              option.icon,
                              color: Colors.blueGrey[800],
                            ),
                            title: Text(
                              option.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _handleMenuSelection(option),
                            selectedTileColor: Colors.blue.withAlpha(21),
                            hoverColor: Colors.blue.withAlpha(26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 18.0,
                      right: 25,
                      top: 4,
                      bottom: 4,
                    ),
                    child: Divider(height: 5, thickness: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.exit_to_app,
                color: Colors.redAccent,
                size: 28,
              ),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _handleLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool desktopWide = screenWidth > 900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 29, 77, 235),
        elevation: 0,
        toolbarHeight: 68,
        title: _buildProfileInfo(),
        actions: desktopWide
            ? [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.home, color: Colors.white, size: 21),
                  label: const Text(
                    'Inicio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.45,
                    ),
                  ),
                  onPressed: _goHome,
                ),
                ..._menuGroups.map((group) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PopupMenuButton<_MenuOption>(
                      tooltip: group.title,
                      offset: const Offset(0, 40),
                      onSelected: _handleMenuSelection,
                      itemBuilder: (context) => group.options
                          .map(
                            (option) => PopupMenuItem<_MenuOption>(
                              value: option,
                              child: Row(
                                children: [
                                  Icon(
                                    option.icon,
                                    size: 20,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(option.title),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: Icon(group.icon, color: Colors.white, size: 20),
                        label: Text(
                          group.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: null,
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(
                    Icons.exit_to_app,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                  tooltip: 'Salir',
                  onPressed: _handleLogout,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(
                    Icons.exit_to_app,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                  tooltip: 'Salir',
                  onPressed: _handleLogout,
                ),
              ],
      ),
      drawer: desktopWide ? null : _buildDrawerMenu(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _mainContentWidget ?? _buildMainContent(),
      ),
    );
  }
}

// Helpers
class _MenuGroup {
  final String title;
  final IconData icon;
  final List<_MenuOption> options;
  const _MenuGroup(this.title, this.icon, this.options);
}

class _MenuOption {
  final String title;
  final IconData icon;
  final Widget? screen;
  const _MenuOption(this.title, this.icon, this.screen);
}
