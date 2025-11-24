import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar_wrapper.dart'; // tambahkan ini
import '../utils/activity_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoriesManagerPage extends StatefulWidget {
  final String storeId;
  final String role; // tambahkan role

  const CategoriesManagerPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<CategoriesManagerPage> createState() => _CategoriesManagerPageState();
}

class _CategoriesManagerPageState extends State<CategoriesManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _selectedOwner;
  String? _selectedCategoryId;
  String _activeForm = 'add';

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

  Future<Map<String, dynamic>> _getCategoryById(String storeId, String categoryId) async {
  final doc = await FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('categories')
      .doc(categoryId)
      .get();

  if (doc.exists) {
    return {
      "id": doc.id,
      ...doc.data()!,
    };
  }

  return {};
}


  Future<void> _addCategory(BuildContext context, String categoryId) async {
  final user = FirebaseAuth.instance.currentUser;
  final name = await _getUserNameByEmail(user?.email ?? "");
  final categoryData = await _getCategoryById(widget.storeId, categoryId);

  await ActivityLogger.log(
    storeId: widget.storeId,
    action: "add_category",
    name: name,
    role: widget.role,
    email: user?.email ?? "",
    desc: "User menambahkan kategori",
    meta: {
      "uid": user?.uid,
      "category": categoryData,
    },
  );
}

  Future<void> _deleteCategory(BuildContext context, String categoryId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final categoryData = await _getCategoryById(widget.storeId, categoryId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "delete_category",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menghapus kategori",
      meta: {
        "uid": user?.uid,
        "category": categoryData,
      },
    );
  }

  Future<void> _editCategory(BuildContext context, String categoryId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final categoryData = await _getCategoryById(widget.storeId, categoryId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "edit_category",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User mengubah kategori",
      meta: {
        "uid": user?.uid,
        "category": categoryData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 Role check: hanya Owner yang bisa akses
    if (widget.role != "Owner") {
      return const Scaffold(
        body: Center(
          child: Text(
            "❌ Akses ditolak\nHalaman ini hanya untuk Owner.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    // 🎨 Warna
    const Color brown = Color(0xFF4B2E2B);
    const Color orange = Color(0xFFFFB56B);
    const Color beige = Color(0xFFFCE8B2);

    // ✨ Halaman utama dibungkus SidebarWrapper
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
                    // === LEFT SIDE: LIST ===
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: orange,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Categories List",
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
                                hintText: 'Search categories...',
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),

                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('stores')
                                    .doc(widget.storeId)
                                    .collection('categories')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  final docs = snapshot.data!.docs.where((doc) {
                                    final name = (doc['name'] ?? '').toString().toLowerCase();
                                    return name.contains(_searchController.text.toLowerCase());
                                  }).toList();

                                  return ListView.builder(
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final category = docs[index];
                                      final bool isSelected = _selectedCategoryId == category.id;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedCategoryId = category.id;
                                            _nameController.text = category['name'] ?? '';
                                            _selectedOwner = category['admin'];
                                            _activeForm = 'edit';
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected ? brown : Colors.transparent,
                                            border: Border.all(color: brown),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                category['name'] ?? 'Unnamed',
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : brown,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                color: isSelected ? Colors.white : Colors.red,
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) {
                                                      return AlertDialog(
                                                        title: const Text("Konfirmasi Hapus"),
                                                        content: const Text("Apakah Anda yakin ingin menghapus kategori ini?"),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context, false),
                                                            child: const Text("Batal"),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red,      // warna tombol
                                                              foregroundColor: Colors.white,    // warna teks
                                                            ),
                                                            onPressed: () => Navigator.pop(context, true),
                                                            child: const Text("Hapus"),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  if (confirm == true) {
                                                    await FirebaseFirestore.instance
                                                        .collection('stores')
                                                        .doc(widget.storeId)
                                                        .collection('categories')
                                                        .doc(category.id)
                                                        .delete();

                                                    await _deleteCategory(context, category.id);
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

                    // === RIGHT SIDE: FORM ===
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: beige,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOGGLE BUTTONS
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _activeForm = 'add';
                                        _selectedCategoryId = null;
                                        _nameController.clear();
                                        _selectedOwner = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'add' ? brown : Colors.transparent,
                                      side: const BorderSide(color: brown),
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
                                      if (_selectedCategoryId == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Pilih kategori terlebih dahulu")),
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _activeForm = 'edit';
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'edit' ? brown : Colors.transparent,
                                      side: const BorderSide(color: brown),
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

                            Text(
                              _activeForm == 'add' ? "Tambah Kategori Baru" : "Edit Kategori",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            const Text("Category Name"),
                            TextField(controller: _nameController),
                            const SizedBox(height: 10),

                            const Text("Admin (Owner)"),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final owners = snapshot.data!.docs;

                                return DropdownButtonFormField<String>(
                                  value: _selectedOwner,
                                  hint: const Text(
                                    'Pilih admin..',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF4B2E2B)),
                                  ),
                                  items: owners.map((doc) => DropdownMenuItem<String>(
                                    value: doc['name'],
                                    child: Text(doc['name']),
                                  )).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedOwner = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF4B2E2B)),
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
                                );
                              },
                            ),

                            const Spacer(),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: Text(_activeForm == 'add'
                                    ? "Tambah Kategori"
                                    : "Simpan Perubahan"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brown,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  if (_nameController.text.isEmpty || _selectedOwner == null) return;

                                  final colRef = FirebaseFirestore.instance
                                      .collection('stores')
                                      .doc(widget.storeId)
                                      .collection('categories');
                                  // simpan context lokal
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                                  if (_activeForm == 'add') {
                                    final newDoc = await colRef.add({
                                      'name': _nameController.text,
                                      'admin': _selectedOwner,
                                    });

                                    await _addCategory(context, newDoc.id);

                                  } else if (_selectedCategoryId != null) {
                                    await colRef.doc(_selectedCategoryId).update({
                                      'name': _nameController.text,
                                      'admin': _selectedOwner,
                                    });

                                    await _editCategory(context, _selectedCategoryId!);
                                  }

                                  if (!mounted) return;

                                  // gunakan context lokal
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(_activeForm == 'add'
                                          ? "Kategori ditambahkan"
                                          : "Kategori diperbarui"),
                                    ),
                                  );

                                  // update state
                                  _nameController.clear();
                                  _selectedOwner = null;
                                  _selectedCategoryId = null;
                                  setState(() {
                                    _activeForm = 'add';
                                  });
                                },
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
}