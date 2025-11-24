import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/activity_logger.dart';

class SizesManagerPage extends StatefulWidget {
  final String storeId;
  final String role;

  const SizesManagerPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<SizesManagerPage> createState() => _SizesManagerPageState();
}

class _SizesManagerPageState extends State<SizesManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAdmin;
  String? _selectedSizeId;
  String _activeForm = 'add';
  bool _isLoading = false;

  Future<Map<String, dynamic>> _getSizeById(String storeId, String sizeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('sizes')
        .doc(sizeId)
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

  Future<void> _addsize(BuildContext context, String sizeId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    
    final sizeData = await _getSizeById(widget.storeId, sizeId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "add_size",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menambahkan ukuran (size)",
      meta: {
        "uid": user?.uid,
        "size": sizeData,
      },
    );
  }

  Future<void> _deletesize(BuildContext context, String sizeId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final sizeData = await _getSizeById(widget.storeId, sizeId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "delete_size",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menghapus ukuran (size)",
      meta: {
        "uid": user?.uid,
        "sizeId": sizeId,
        "size": sizeData,
      },
    );
  }


  Future<void> _editsize(BuildContext context, String sizeId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final sizeData = await _getSizeById(widget.storeId, sizeId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "edit_size",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User mengubah ukuran (size)",
      meta: {
        "uid": user?.uid,
        "size": sizeData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color brown = const Color(0xFF4B2E2B);
    final Color orange = const Color(0xFFFFB56B);
    final Color beige = const Color(0xFFFCE8B2);

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
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    // LEFT SIDE LIST
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: orange,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Sizes List",
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
                                hintText: 'Search sizes...',
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),

                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('stores')
                                    .doc(widget.storeId)
                                    .collection('sizes')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  final docs = snapshot.data!.docs.where((doc) {
                                    final name =
                                        (doc['name'] ?? '').toString().toLowerCase();
                                    return name.contains(_searchController.text.toLowerCase());
                                  }).toList();

                                  return ListView.builder(
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final size = docs[index];
                                      final bool isSelected = _selectedSizeId == size.id;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedSizeId = size.id;
                                            _nameController.text = size['name'] ?? '';
                                            _selectedAdmin = size['admin'];
                                            _activeForm = 'edit';
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected ? brown : Colors.transparent,
                                            border: Border.all(color: brown),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                size['name'] ?? 'Unnamed',
                                                style: TextStyle(
                                                  color:
                                                      isSelected ? Colors.white : brown,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                color:
                                                    isSelected ? Colors.white : Colors.red,
                                                onPressed: () async {
                                                  // 🔥 ALERT KONFIRMASI DELETE
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text("Konfirmasi Hapus"),
                                                      content: Text(
                                                        "Yakin ingin menghapus size \"${size['name']}\"?"
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text("Batal"),
                                                          onPressed: () => Navigator.pop(context, false),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.red,
                                                            foregroundColor: Colors.white, // <-- warna teks putih
                                                          ),
                                                          child: const Text("Hapus"),
                                                          onPressed: () => Navigator.pop(context, true),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm != true) return;
                                                  await _deletesize(context, size.id);
                                                  await FirebaseFirestore.instance
                                                      .collection('stores')
                                                      .doc(widget.storeId)
                                                      .collection('sizes')
                                                      .doc(size.id)
                                                      .delete();
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

                    // RIGHT SIDE FORM
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: beige,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _activeForm = 'add';
                                        _selectedSizeId = null;
                                        _nameController.clear();
                                        _selectedAdmin = null;
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
                                    onPressed: () {
                                      if (_selectedSizeId == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text("Pilih size terlebih dahulu")),
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
                                        color: _activeForm == 'edit'
                                            ? Colors.white
                                            : brown,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Text(
                              _activeForm == 'add'
                                  ? "Tambah Size Baru"
                                  : "Edit Size",
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            const Text("Size Name"),
                            TextField(controller: _nameController),
                            const SizedBox(height: 10),

                            const Text("Admin"),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                return DropdownButtonFormField<String>(
                                  value: _selectedAdmin,
                                  hint: const Text(
                                    'Pilih admin..',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF4B2E2B)), // coklat tua
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent, // background transparan
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
                                  items: snapshot.data!.docs.map((doc) {
                                    final userName = doc['name'] ?? 'Tanpa Nama';
                                    return DropdownMenuItem<String>(
                                      value: userName,
                                      child: Text(userName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAdmin = value;
                                    });
                                  },
                                );
                              },
                            ),

                            const Spacer(),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_activeForm == 'add'
                                    ? "Tambah Size"
                                    : "Simpan Perubahan"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brown,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isLoading ? null : () async {
                                  if (_nameController.text.isEmpty || _selectedAdmin == null) return;

                                  setState(() => _isLoading = true); // mulai loading

                                  final colRef = FirebaseFirestore.instance
                                      .collection('stores')
                                      .doc(widget.storeId)
                                      .collection('sizes');

                                  try {
                                    if (_activeForm == 'add') {
                                      final newDoc= await colRef.add({
                                        'name': _nameController.text,
                                        'admin': _selectedAdmin,
                                      });
                                      await _addsize(context, newDoc.id);
                                    } else if (_selectedSizeId != null) {
                                      await colRef.doc(_selectedSizeId).update({
                                        'name': _nameController.text,
                                        'admin': _selectedAdmin,
                                      });
                                      await _editsize(context, _selectedSizeId!);
                                    }

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_activeForm == 'add'
                                            ? "Size ditambahkan"
                                            : "Size diperbarui"),
                                      ),
                                    );

                                    _nameController.clear();
                                    _selectedAdmin = null;
                                    _selectedSizeId = null;
                                    setState(() {
                                      _activeForm = 'add';
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Terjadi kesalahan: $e"),
                                      ),
                                    );
                                  } finally {
                                    setState(() => _isLoading = false); // selesai loading
                                  }
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
