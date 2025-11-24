import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar_wrapper.dart'; // gunakan wrapper di sini
import '../utils/activity_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeliveriesManagerPage extends StatefulWidget {
  final String storeId;
  final String role;

  const DeliveriesManagerPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<DeliveriesManagerPage> createState() => _DeliveriesManagerPageState();
}

class _DeliveriesManagerPageState extends State<DeliveriesManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAdmin;
  String? _selectedDeliveryId;
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

  Future<Map<String, dynamic>> _getDeliveryById(String storeId, String deliveryId) async {
  final doc = await FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('deliveries')
      .doc(deliveryId)
      .get();

  if (doc.exists) {
    return {
      "id": doc.id,
      ...doc.data()!,
    };
  }

  return {};
}


  Future<void> _addDelivery(BuildContext context, String deliveryId) async {
  final user = FirebaseAuth.instance.currentUser;
  final name = await _getUserNameByEmail(user?.email ?? "");
  final deliveryData = await _getDeliveryById(widget.storeId, deliveryId);

  await ActivityLogger.log(
    storeId: widget.storeId,
    action: "add_delivery",
    name: name,
    role: widget.role,
    email: user?.email ?? "",
    desc: "User menambahkan pengantaran (delivery)",
    meta: {
      "uid": user?.uid,
      "delivery": deliveryData,
    },
  );
}

  Future<void> _deleteDelivery(BuildContext context, String deliveryId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final deliveryData = await _getDeliveryById(widget.storeId, deliveryId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "delete_delivery",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menghapus pengantaran (Delivery)",
      meta: {
        "uid": user?.uid,
        "delivery": deliveryData,
      },
    );
  }

  Future<void> _editDelivery(BuildContext context, String deliveryId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final deliveryData = await _getDeliveryById(widget.storeId, deliveryId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "edit_delivery",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User mengubah pengantaran (Delivery)",
      meta: {
        "uid": user?.uid,
        "delivery": deliveryData,
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

              // BODY
              Expanded(
                child: Row(
                  children: [
                    // LEFT SIDE (List)
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: orange,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Deliveries List",
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
                                hintText: 'Search Deliveries...',
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
                                    .collection('deliveries')
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
                                      final delivery = docs[index];
                                      final bool isSelected = _selectedDeliveryId == delivery.id;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedDeliveryId = delivery.id;
                                            _nameController.text = delivery['name'] ?? '';
                                            _selectedAdmin = delivery['admin'];
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
                                                delivery['name'] ?? 'Unnamed',
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
                                                    builder: (ctx) {
                                                      return AlertDialog(
                                                        title: const Text("Hapus Delivery?"),
                                                        content: Text(
                                                            "Apakah kamu yakin ingin menghapus delivery '${delivery['name']}' ?"),
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
                                                    // Jalankan proses hapus
                                                    await FirebaseFirestore.instance
                                                        .collection('stores')
                                                        .doc(widget.storeId)
                                                        .collection('deliveries')
                                                        .doc(delivery.id)
                                                        .delete();

                                                    await _deleteDelivery(context, delivery.id);

                                                    // Snackbar informasi
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text("Delivery berhasil dihapus")),
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
                            // TOGGLE BUTTONS
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _activeForm = 'add';
                                        _selectedDeliveryId = null;
                                        _nameController.clear();
                                        _selectedAdmin = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'add' ? brown : Colors.transparent,
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
                                      if (_selectedDeliveryId == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Pilih delivery terlebih dahulu")),
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _activeForm = 'edit';
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _activeForm == 'edit' ? brown : Colors.transparent,
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

                            Text(
                              _activeForm == 'add' ? "Tambah Delivery Baru" : "Edit Delivery",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            const Text("Delivery Name"),
                            TextField(controller: _nameController),
                            const SizedBox(height: 10),

                            const Text("Admin"),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final users = snapshot.data!.docs;

                                return DropdownButtonFormField<String>(
                                  value: _selectedAdmin,
                                  hint: const Text(
                                    'Pilih admin...',
                                    textAlign: TextAlign.center, // teks di tengah
                                    style: TextStyle(color: Colors.brown), // warna teks placeholder
                                  ),
                                  items: users.map((doc) {
                                    return DropdownMenuItem<String>(
                                      value: doc['name'],
                                      child: Text(doc['name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAdmin = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent, // transparan
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12), // sudut agak tumpul
                                      borderSide: const BorderSide(color: Color(0xFF4B2E2B)), // coklat tua
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF4B2E2B)), // coklat tua
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
                                    ? "Tambah Delivery"
                                    : "Simpan Perubahan"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brown,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  if (_nameController.text.isEmpty || _selectedAdmin == null) return;

                                  final colRef = FirebaseFirestore.instance
                                      .collection('stores')
                                      .doc(widget.storeId)
                                      .collection('deliveries');

                                  // simpan ScaffoldMessenger lokal sebelum await
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                                  if (_activeForm == 'add') {
                                    final newDoc= await colRef.add({
                                      'name': _nameController.text,
                                      'admin': _selectedAdmin,
                                    });
                                    await _addDelivery(context, newDoc.id);
                                  } else if (_selectedDeliveryId != null) {
                                    await colRef.doc(_selectedDeliveryId).update({
                                      'name': _nameController.text,
                                      'admin': _selectedAdmin,
                                    });
                                    await _editDelivery(context, _selectedDeliveryId!);
                                  }

                                  if (!mounted) return;

                                  // tampilkan snackbar pakai variabel lokal
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(_activeForm == 'add'
                                          ? "Delivery ditambahkan"
                                          : "Delivery diperbarui"),
                                    ),
                                  );

                                  // reset form
                                  _nameController.clear();
                                  _selectedAdmin = null;
                                  _selectedDeliveryId = null;
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
