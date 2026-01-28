// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registeruser_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String rol;
  final String? phone;
  final String? address;
  final String? department;
  final String? position;
  final String? photoUrl;
  final String? status;
  final String? gender;
  final DateTime? birthDate;
  final DateTime? entryDate;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.rol,
    this.phone,
    this.address,
    this.department,
    this.position,
    this.photoUrl,
    this.status,
    this.gender,
    this.birthDate,
    this.entryDate,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      rol: data['rol'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      department: data['department'] ?? '',
      position: data['position'] ?? '',
      photoUrl: data['photoUrl'],
      status: data['status'] ?? '',
      gender: data['gender'] ?? '',
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
      entryDate: data['entryDate'] != null
          ? (data['entryDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'rol': rol,
      'phone': phone,
      'address': address,
      'department': department,
      'position': position,
      'photoUrl': photoUrl,
      'status': status,
      'gender': gender,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'entryDate': entryDate != null ? Timestamp.fromDate(entryDate!) : null,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? rol,
    String? phone,
    String? address,
    String? department,
    String? position,
    String? photoUrl,
    String? status,
    String? gender,
    DateTime? birthDate,
    DateTime? entryDate,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      department: department ?? this.department,
      position: position ?? this.position,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      entryDate: entryDate ?? this.entryDate,
    );
  }
}

class UserService {
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');

  Future<List<UserModel>> getAllUsers() async {
    final querySnapshot = await usersCollection.get();
    return querySnapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
  }

  Future<void> addUser(UserModel user) async {
    await usersCollection.add(user.toMap());
  }

  Future<void> updateUser(UserModel user) async {
    await usersCollection.doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String id) async {
    await usersCollection.doc(id).delete();
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = UserService().getAllUsers();
    });
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este usuario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await UserService().deleteUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario eliminado'),
          backgroundColor: Colors.red,
        ),
      );
      _refreshUsers();
    }
  }

  void _editUser(UserModel user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditUserScreen(user: user)),
    );
    _refreshUsers();
  }

  void _addUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisteruserScreen()),
    );
    _refreshUsers();
  }

  Widget _buildRoleChip(String rol) {
    return Chip(
      label: Text(
        rol.isNotEmpty ? (rol[0].toUpperCase() + rol.substring(1)) : '',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: rol == 'administrador' ? Colors.indigo : Colors.green,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildResponsiveUserList(List<UserModel> users) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 700;

    if (isMobile) {
      // Lista tipo tarjeta para móvil
      return ListView.separated(
        itemCount: users.length,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final u = users[index];
          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRoleChip(u.rol),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(u.email, style: const TextStyle(fontSize: 15)),
                  if (u.phone != null && u.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Tel: ${u.phone!}",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  if (u.department != null && u.department!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Depto: ${u.department!}",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: "Editar",
                        icon: const Icon(Icons.edit, color: Colors.indigo),
                        onPressed: () => _editUser(u),
                      ),
                      IconButton(
                        tooltip: "Eliminar",
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(u.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Modo DataTable para pantalla ancha
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
          child: Card(
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 48,
                    dataRowMinHeight: 70,
                    dataRowMaxHeight: 90,
                    headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                      (Set<WidgetState> states) => Colors.indigo[100],
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Nombre',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Correo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Rol',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Acciones',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    rows: users.map((user) {
                      return DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          DataCell(_buildRoleChip(user.rol)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Editar',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.indigo,
                                      size: 28,
                                    ),
                                    onPressed: () => _editUser(user),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Eliminar',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 28,
                                    ),
                                    onPressed: () => _deleteUser(user.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUsers,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      backgroundColor: Colors.indigo[50],
      body: FutureBuilder<List<UserModel>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay usuarios registrados.',
                style: TextStyle(fontSize: 22),
              ),
            );
          }
          final users = snapshot.data!;
          return _buildResponsiveUserList(users);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add, size: 28),
        label: const Text('Nuevo usuario', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.indigo,
        elevation: 6,
      ),
    );
  }
}

class EditUserScreen extends StatefulWidget {
  final UserModel user;
  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _departmentController;
  late TextEditingController _positionController;
  late String _selectedRol;
  late String? _selectedGender;
  late String? _selectedStatus;
  DateTime? _birthDate;
  DateTime? _entryDate;
  String? _photoUrl;
  XFile? _profileImage;
  bool _isLoading = false;

  final List<String> _genders = ['Masculino', 'Femenino', 'Otro'];
  final List<String> _statuses = ['activo', 'inactivo'];
  final List<String> _roles = ['administrador', 'colaborador'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _departmentController = TextEditingController(
      text: widget.user.department ?? '',
    );
    _positionController = TextEditingController(
      text: widget.user.position ?? '',
    );
    _selectedRol = widget.user.rol;
    _selectedGender = widget.user.gender != '' ? widget.user.gender : null;
    _selectedStatus = widget.user.status != '' ? widget.user.status : null;
    _birthDate = widget.user.birthDate;
    _entryDate = widget.user.entryDate;
    _photoUrl = widget.user.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _profileImage = picked;
      });
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_profileImage == null) return _photoUrl;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$uid.jpg');
    final bytes = await _profileImage!.readAsBytes();
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  void _updateUser() async {
    setState(() {
      _isLoading = true;
    });
    String? newPhotoUrl = await _uploadProfileImage(widget.user.id);

    final updatedUser = widget.user.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      department: _departmentController.text.trim(),
      position: _positionController.text.trim(),
      photoUrl: newPhotoUrl,
      rol: _selectedRol,
      gender: _selectedGender,
      status: _selectedStatus,
      birthDate: _birthDate,
      entryDate: _entryDate,
    );
    await UserService().updateUser(updatedUser);

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Usuario actualizado'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar usuario'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 12,
              color: Colors.white.withAlpha(240),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: FutureBuilder<Uint8List?>(
                          future: _profileImage?.readAsBytes(),
                          builder: (context, snapshot) {
                            if (_profileImage != null && snapshot.hasData) {
                              return CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.indigo[100],
                                backgroundImage: MemoryImage(snapshot.data!),
                              );
                            } else if (_photoUrl != null &&
                                _photoUrl!.isNotEmpty) {
                              return CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.indigo[100],
                                backgroundImage: NetworkImage(_photoUrl!),
                              );
                            } else {
                              return CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.indigo[100],
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: Colors.indigo,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Correo',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _addressController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Dirección',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.home),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _birthDate ?? DateTime(2000, 1, 1),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _birthDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Fecha de nacimiento',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  _birthDate == null
                                      ? 'Selecciona fecha'
                                      : "${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}",
                                  style: TextStyle(
                                    color: _birthDate == null
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _entryDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 5),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _entryDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Fecha de ingreso',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  _entryDate == null
                                      ? 'Selecciona fecha'
                                      : "${_entryDate!.day.toString().padLeft(2, '0')}/${_entryDate!.month.toString().padLeft(2, '0')}/${_entryDate!.year}",
                                  style: TextStyle(
                                    color: _entryDate == null
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _departmentController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Departamento o área',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.apartment),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _positionController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Puesto o cargo',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.work),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Género',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        },
                        items: _genders
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatus = newValue;
                          });
                        },
                        items: _statuses
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s[0].toUpperCase() + s.substring(1),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRol,
                        decoration: InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRol = newValue!;
                          });
                        },
                        items: _roles
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r[0].toUpperCase() + r.substring(1),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _updateUser,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.indigo,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.save,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Guardar cambios',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
