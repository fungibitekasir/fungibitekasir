import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/sidebar_wrapper.dart';
import '../utils/activity_logger.dart';
import 'package:fungibite_kasir/firebase_secondary.dart';


class AdminManagerPage extends StatefulWidget {
  final String storeId;
  final String role; // contoh: "Owner" atau "Staff"

  const AdminManagerPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<AdminManagerPage> createState() => _AdminManagerPageState();
}

class _AdminManagerPageState extends State<AdminManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

    Future<Map<String, dynamic>> _getAdminById(String adminId) async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();

      if (doc.exists) {
        return {
          "id": doc.id,
          ...doc.data()!,
        };
      }

      return {};
    }



  Future<String> _getUserNameByEmail(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['name'] ?? "Unknown";
    }

    return "Unknown";
  }

  Future<void> _addAdmin(BuildContext context, String adminId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final adminData = await _getAdminById(adminId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "add_admin",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menambahkan admin",
      meta: {
        "uid": user?.uid,
        "admin": adminData,
      },
    );
  }

  Future<void> _deleteAdmin(BuildContext context, String adminId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final adminData = await _getAdminById(adminId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "delete_admin",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menghapus admin",
      meta: {
        "uid": user?.uid,
        "admin": adminData,
      },
    );
  }

  Future<void> _editAdmin(BuildContext context, String adminId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final adminData = await _getAdminById(adminId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "edit_admin",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User mengubah admin",
      meta: {
        "uid": user?.uid,
        "admin": adminData,
      },
    );
  }


  String? _selectedRole;
  String? _selectedUserId;
  String _activeForm = 'add';

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    if (widget.role != "Owner") {
      return Scaffold(
        body: Center(
          child: Text(
            "Anda tidak memiliki akses ke halaman ini.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final Color brown = const Color(0xFF4B2E2B);
    final Color orange = const Color(0xFFFFB56B);
    final Color beige = const Color(0xFFFCE8B2);

    // ✅ Bungkus seluruh halaman dalam SidebarWrapper
    return SidebarWrapper(
      storeId: widget.storeId,
      role: widget.role,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // HEADER
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.account_circle, size: 32, color: Colors.brown),
                    const SizedBox(width: 8),
                    Text(
                      "Hi, ${widget.role}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                  ],
                ),
              ),

              // ISI HALAMAN
              Expanded(
                child: Row(
                  children: [
                    // LEFT SIDE (List Admin)
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: orange,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Admin List",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search admin...',
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }

                                  final docs = snapshot.data!.docs.where((doc) {
                                    final name = (doc['name'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    return name.contains(
                                        _searchController.text.toLowerCase());
                                  }).toList();

                                  return ListView.builder(
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final user = docs[index];
                                      final bool isSelected =
                                          _selectedUserId == user.id;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                          _selectedUserId = user.id;
                                          _nameController.text = user['name'] ?? '';
                                          _ownerController.text = user['owner'] ?? '';
                                          _emailController.text = user['email'] ?? '';
                                          _usernameController.text = user['username'] ?? '';
                                          _selectedRole = user['role'];
                                          _activeForm = 'edit';
                                        });
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? brown
                                                : Colors.transparent,
                                            border: Border.all(color: brown),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                user['name'] ?? 'No Name',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : brown,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.red,
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) {
                                                      return AlertDialog(
                                                        title: const Text("Hapus Admin?"),
                                                        content: Text(
                                                          "Apakah Anda yakin ingin menghapus admin '${user['name']}' ?",
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx, false),
                                                            child: const Text("Batal"),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red,
                                                              foregroundColor: Colors.white,
                                                            ),
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            child: const Text("Hapus"),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );

                                                  if (confirm == true) {
                                                    await FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(user.id)
                                                        .delete();

                                                    await _deleteAdmin(context, user.id);

                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text("Admin berhasil dihapus")),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // RIGHT SIDE (Form)
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: beige,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔥 FIXED — TIDAK SCROLL
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _activeForm = 'add';
                                        _selectedUserId = null;
                                        _nameController.clear();
                                        _ownerController.clear();
                                        _emailController.clear();
                                        _usernameController.clear();
                                        _passwordController.clear();
                                        _selectedRole = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'add'
                                          ? brown
                                          : Colors.transparent,
                                      side: BorderSide(color: brown),
                                    ),
                                    child: Text(
                                      "Add",
                                      style: TextStyle(
                                        color: _activeForm == 'add' ? Colors.white : brown,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (_selectedUserId == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Pilih admin terlebih dahulu")),
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _activeForm = 'edit';
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'edit'
                                          ? brown
                                          : Colors.transparent,
                                      side: BorderSide(color: brown),
                                    ),
                                    child: Text(
                                      "Edit",
                                      style: TextStyle(
                                        color: _activeForm == 'edit' ? Colors.white : brown,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // 🔥 INI YANG SCROLL
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _activeForm == 'add' ? "Tambah Admin Baru" : "Edit Admin",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    const Text("Username"),
                                    TextField(controller: _usernameController),
                                    const SizedBox(height: 10),

                                    const Text("Name"),
                                    TextField(controller: _nameController),
                                    const SizedBox(height: 10),

                                    const Text("Owner"),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .where('role', isEqualTo: 'Owner')
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const CircularProgressIndicator();
                                        }

                                        return DropdownButtonFormField<String>(
                                          value: _ownerController.text.isNotEmpty ? _ownerController.text : null,
                                          hint: const Text(
                                            'Pilih owner..',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Color(0xFF4B2E2B)), // coklat tua
                                          ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.transparent, // transparan
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12), // sudut agak tumpul
                                              borderSide: const BorderSide(color: Color(0xFF4B2E2B)), // garis coklat tua
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF4B2E2B)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF4B2E2B), width: 2),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          ),
                                          dropdownColor: Colors.white, // warna dropdown saat dibuka
                                          items: snapshot.data!.docs.map((owner) {
                                            final ownerName = owner['name'] ?? 'No Name';
                                            return DropdownMenuItem<String>(
                                              value: ownerName,
                                              child: Text(ownerName),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _ownerController.text = value ?? '';
                                            });
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),

                                    const Text("Role"),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _selectedRole == 'Kasir',
                                          onChanged: (_) {
                                            setState(() => _selectedRole = 'Kasir');
                                          },
                                        ),
                                        const Text("Kasir"),
                                        const SizedBox(width: 20),
                                        Checkbox(
                                          value: _selectedRole == 'Owner',
                                          onChanged: (_) {
                                            setState(() => _selectedRole = 'Owner');
                                          },
                                        ),
                                        const Text("Owner"),
                                      ],
                                    ),

                                    const Text("E-mail"),
                                    TextField(controller: _emailController),

                                    if (_activeForm == 'add') ...[
                                      const SizedBox(height: 10),
                                      const Text("Password"),
                                      TextField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),

                            // 🔥 FIXED — TIDAK SCROLL
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF4B2E2B),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                    _activeForm == 'add'
                                        ? "Tambah Admin"
                                        : "Simpan Perubahan",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brown,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isLoading ? null : _saveAdmin,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAdmin() async {
  if (_nameController.text.isEmpty ||
      _emailController.text.isEmpty ||
      _usernameController.text.isEmpty ||
      _selectedRole == null ||
      (_activeForm == 'add' && _passwordController.text.isEmpty)) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lengkapi semua data terlebih dahulu")),
    );
    return;
  }

  setState(() => _isLoading = true); // 🔥 tampilkan loading sebelum mulai proses
  await Future.delayed(Duration.zero); // 🔥 paksa rebuild UI agar spinner muncul

  try {
    final usersRef = FirebaseFirestore.instance.collection('users');

    if (_activeForm == 'add') {
      final secondaryApp = await SecondaryFirebase.secondaryApp;
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final newUser = await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await usersRef.doc(newUser.user!.uid).set({
        'username': _usernameController.text,
        'name': _nameController.text,
        'owner': _ownerController.text,
        'email': _emailController.text,
        'role': _selectedRole,
        'storeId': widget.storeId,
      });

      await _addAdmin(context, newUser.user!.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin baru berhasil dibuat.")),
        );
      }
    } else if (_selectedUserId != null) {
      await usersRef.doc(_selectedUserId!).update({
        'username': _usernameController.text,
        'name': _nameController.text,
        'owner': _ownerController.text,
        'email': _emailController.text,
        'role': _selectedRole,
        'storeId': widget.storeId,
      });

      await _editAdmin(context, _selectedUserId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data admin diperbarui.")),
        );
      }
    }

    // Bersihkan form
    _nameController.clear();
    _ownerController.clear();
    _emailController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _selectedRole = null;
    _selectedUserId = null;

    if (mounted) {
      setState(() {
        _activeForm = 'add';
      });
    }
  } on FirebaseAuthException catch (e) {
    String message = "Terjadi kesalahan.";
    if (e.code == 'email-already-in-use') {
      message = "Email sudah digunakan.";
    } else if (e.code == 'weak-password') {
      message = "Password terlalu lemah (minimal 6 karakter).";
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false); // 🔥 sembunyikan loading setelah selesai
    }
  }
}
}
