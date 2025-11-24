import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar_wrapper.dart';
import '../utils/activity_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuManagerPage extends StatefulWidget {
  final String storeId;
  final String role;

  const MenuManagerPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<MenuManagerPage> createState() => _MenuManagerPageState();
}

class _MenuManagerPageState extends State<MenuManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _menuNameController = TextEditingController();
  final Map<String, TextEditingController> _priceControllers = {};

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

  Future<Map<String, dynamic>> _getMenuById(String storeId, String menuId) async {
  final doc = await FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('menus')
      .doc(menuId)
      .get();

  if (doc.exists) {
    return {
      "id": doc.id,
      ...doc.data()!,
    };
  }

  return {};
}

  Future<void> _addMenu(BuildContext context, String menuId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final menuData = await _getMenuById(widget.storeId, menuId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "add_menu",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menambahkan Menu",
      meta: {"uid": user?.uid, "menu": menuData},
    );
  }

  Future<void> _deleteMenu(BuildContext context,String menuId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final menuData = await _getMenuById(widget.storeId, menuId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "delete_menu",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menghapus Menu",
      meta: {"uid": user?.uid, "menu": menuData},
    );
  }

  Future<void> _editMenu(BuildContext context, String menuId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final menuData = await _getMenuById(widget.storeId, menuId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "edit_menu",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User mengubah menu",
      meta: {"uid": user?.uid, "menu": menuData},
    );
  }

  String? _selectedMenuId;
  String _activeForm = 'add';
  String? _selectedAdminId;
  String? _selectedAdminName;

  final Color brown = const Color(0xFF4B2E2B);
  final Color orange = const Color(0xFFFFB56B);
  final Color beige = const Color(0xFFFCE8B2);

  Map<String, bool> sizes = {};
  Map<String, bool> categories = {};

  @override
  void initState() {
    super.initState();
    _loadSizes();
    _loadCategories();
  }

  Future<void> _loadSizes() async {
    final sizeSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('sizes')
        .get();

    // Normalisasi nama dan hilangkan duplikat No Size
    final Map<String, bool> cleaned = {};

    for (var doc in sizeSnap.docs) {
      String rawName = (doc['name'] ?? 'Unnamed').toString();

      // Samakan penulisan "No Size" dari data supaya hanya 1
      String name = rawName.toLowerCase() == 'no size'
          ? 'No Size'
          : rawName;

      // Hindari duplikasi
      cleaned[name] = false;
    }

    setState(() {
      sizes = cleaned;

      // Buat price controller sesuai size final
      _priceControllers.clear();
      for (var key in sizes.keys) {
        _priceControllers[key] = TextEditingController();
      }
    });
  }


  Future<void> _loadCategories() async {
    final catSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('categories')
        .get();

    setState(() {
      categories = {
        for (var doc in catSnap.docs) (doc['name'] ?? 'Unnamed'): false
      };
    });
  }

  bool get isNoSizeSelected =>
      sizes.entries.any((e) => e.key.toLowerCase() == 'no size' && e.value);

  @override
  Widget build(BuildContext context) {
    final storeMenusRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('menus');

    return SidebarWrapper(
      storeId: widget.storeId,
      role: widget.role,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
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

              Expanded(
                child: Row(
                  children: [
                    // LEFT
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: orange,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Menu List",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 10),

                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Type some keywords..',
                                fillColor: Colors.white,
                                filled: true,
                                suffixIcon: const Icon(Icons.search),
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
                                stream: storeMenusRef.snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                  final docs = snapshot.data!.docs.where((doc) {
                                    final name =
                                        (doc['name'] ?? '').toString().toLowerCase();
                                    return name.contains(
                                        _searchController.text.toLowerCase());
                                  }).toList();

                                  return ListView.builder(
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final menu = docs[index];
                                      final isSelected =
                                          _selectedMenuId == menu.id;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_selectedMenuId == menu.id) {
                                              _resetForm();
                                            } else {
                                              _selectedMenuId = menu.id;
                                              _activeForm = 'edit';

                                              _menuNameController.text =
                                                  menu['name'] ?? '';
                                              _selectedAdminId = menu['admin_id'];
                                              _selectedAdminName =
                                                  menu['admin_name'];

                                              sizes.updateAll((key, _) =>
                                                  menu['sizes']?.contains(key) ??
                                                  false);

                                              categories.updateAll((key, _) =>
                                                  menu['categories']
                                                          ?.contains(key) ??
                                                      false);

                                              if (menu['price'] != null) {
                                                menu['price'].forEach((k, v) {
                                                  _priceControllers[k]?.text =
                                                      v.toString();
                                                });
                                              }
                                            }
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
                                              Text(menu['name'] ?? 'Unnamed',
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : brown,
                                                  )),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.red,
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text("Konfirmasi Hapus"),
                                                      content: const Text("Apakah Anda ingin menghapus menu ini?"),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: const Text("Batal"),
                                                        ),

                                                        // 🔥 TOMBOL HAPUS MERAH + TEKS PUTIH
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.red,      // merah solid
                                                            foregroundColor: Colors.white,    // teks putih
                                                          ),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text("Hapus"),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await storeMenusRef
                                                        .doc(menu.id)
                                                        .delete();
                                                    await _deleteMenu(context, menu.id);
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

                    // RIGHT (FORM)
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: beige,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// TOGGLE BUTTON
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(_resetForm),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'add'
                                          ? brown
                                          : Colors.transparent,
                                      side: BorderSide(color: brown),
                                    ),
                                    child: Text(
                                      "Add",
                                      style: TextStyle(
                                        color: _activeForm == 'add'
                                            ? Colors.white
                                            : brown,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _selectedMenuId != null
                                        ? () =>
                                            setState(() => _activeForm = 'edit')
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'edit'
                                          ? brown
                                          : Colors.transparent,
                                      side: BorderSide(color: brown),
                                    ),
                                    child: Text(
                                      "Edit",
                                      style: TextStyle(
                                        color: _activeForm == 'edit'
                                            ? Colors.white
                                            : (_selectedMenuId == null
                                                ? Colors.grey
                                                : brown),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            /// SCROLLABLE FORM AREA (FIX)
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Nama Menu"),
                                    TextField(controller: _menuNameController),
                                    const SizedBox(height: 10),

                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text("Size"),
                                              ...sizes.keys.map((key) {
                                                final isNoSizeKey = key == 'No Size';
                                                return CheckboxListTile(
                                                  value: sizes[key],
                                                  title: Text(key),
                                                  controlAffinity: ListTileControlAffinity.leading,
                                                  onChanged: (v) {
                                                    setState(() {
                                                      if (isNoSizeKey) {
                                                        // Jika No Size dipilih → matikan semua size lain
                                                        sizes.updateAll((k, val) => k == 'No Size');

                                                        // Hapus harga size lain
                                                        _priceControllers.forEach((k, c) {
                                                          if (k != 'No Size') c.clear();
                                                        });
                                                      } else {
                                                        // Jika memilih size normal, matikan No Size
                                                        sizes['No Size'] = false;

                                                        sizes[key] = v ?? false;
                                                      }
                                                    });
                                                  },
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text("Categories"),
                                              Wrap(
                                                spacing: 8,
                                                children: categories.keys
                                                    .map((key) {
                                                  return Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Checkbox(
                                                        value: categories[key],
                                                        onChanged: (v) =>
                                                            setState(() =>
                                                                categories[key] =
                                                                    v ?? false),
                                                      ),
                                                      Text(key),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    const Text("Harga"),
                                    ...sizes.entries
                                        .where((e) => e.value)
                                        .map((e) {
                                      return TextField(
                                        controller:
                                            _priceControllers[e.key],
                                        decoration: InputDecoration(
                                            labelText: e.key),
                                        keyboardType: TextInputType.number,
                                      );
                                    }),

                                    const SizedBox(height: 10),

                                    const Text("Admin / Dimasukkan oleh"),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                              child:
                                                  CircularProgressIndicator());
                                        }
                                        return DropdownButtonFormField<String>(
                                          value: _selectedAdminId,
                                          hint: const Text(
                                            'Pilih admin...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Color(0xFF4B2E2B)),
                                          ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.transparent, // transparan
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12), // sudut agak tumpul
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
                                          items: snapshot.data!.docs.map((doc) {
                                            final userId = doc.id;
                                            final userName = doc['name'] ?? 'Tanpa Nama';
                                            return DropdownMenuItem<String>(
                                              value: userId,
                                              child: Text(userName),
                                            );
                                          }).toList(),
                                          onChanged: (selectedId) {
                                            if (selectedId == null) return;
                                            final selectedDoc = snapshot.data!.docs
                                                .firstWhere((doc) => doc.id == selectedId);
                                            setState(() {
                                              _selectedAdminId = selectedId;
                                              _selectedAdminName = selectedDoc['name'] ?? 'Tanpa Nama';
                                            });
                                          },
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),

                            /// SAVE BUTTON (FIXED)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: Text(
                                  _activeForm == 'add'
                                      ? "Tambah Menu"
                                      : "Simpan Perubahan",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brown,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final menuId = await _saveMenu(storeMenusRef); // ← ambil ID menu

                                  if (menuId == null) return;

                                  if (_activeForm == 'add') {
                                    await _addMenu(context, menuId);
                                  } else {
                                    await _editMenu(context, menuId);
                                  }

                                  _resetForm();
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

  void _resetForm() {
    _menuNameController.clear();
    _priceControllers.forEach((k, v) => v.clear());
    sizes.updateAll((k, v) => false);
    categories.updateAll((k, v) => false);
    _selectedMenuId = null;
    _selectedAdminId = null;
    _selectedAdminName = null;
    _activeForm = 'add';
  }

  Future<String?> _saveMenu(CollectionReference<Map<String, dynamic>> ref) async {
  final name = _menuNameController.text.trim();
  if (name.isEmpty) return null;

  final price = <String, num>{};

  sizes.forEach((k, v) {
    if (v && _priceControllers[k]?.text.isNotEmpty == true) {
      final raw = double.tryParse(_priceControllers[k]!.text) ?? 0;

      if (raw == raw.toInt()) {
        price[k] = raw.toInt();
      } else {
        price[k] = raw;
      }
    }
  });

  final data = {
    'name': name,
    'sizes': sizes.entries.where((e) => e.value).map((e) => e.key).toList(),
    'categories': categories.entries.where((e) => e.value).map((e) => e.key).toList(),
    'price': price,
    'admin_id': _selectedAdminId,
    'admin_name': _selectedAdminName ?? 'Tanpa Nama',
    'created_at': FieldValue.serverTimestamp(),
  };

  if (_activeForm == 'add') {
    final newDoc = await ref.add(data); // <-- NEW
    return newDoc.id;                  // <-- return id
  } else if (_selectedMenuId != null) {
    await ref.doc(_selectedMenuId!).update(data);
    return _selectedMenuId;            // <-- return existing id
  }

  return null;
}
}