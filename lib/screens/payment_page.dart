import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar_wrapper.dart';
import '../utils/activity_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentsManagerPage extends StatefulWidget {
  final String storeId;
  final String role;

  const PaymentsManagerPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<PaymentsManagerPage> createState() => _PaymentsManagerPageState();
}

class _PaymentsManagerPageState extends State<PaymentsManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _selectedPaymentId;
  String _activeForm = 'add';
  String? _selectedAdminId;

  Stream<QuerySnapshot> _getAdmins() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots();
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

  Future<Map<String, dynamic>> _getPaymentById(String storeId, String paymentId) async {
    final doc = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('payments')
        .doc(paymentId)
        .get();

    if (doc.exists) {
      return {
        "id": doc.id,
        ...doc.data()!,
      };
    }

    return {};
  }


  Future<void> _addPayment(BuildContext context, String paymentId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final paymentData = await _getPaymentById(widget.storeId, paymentId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "add_payment",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menambahkan metode pembayaran",
      meta: {"uid": user?.uid, "payment": paymentData },
    );
  }

  Future<void> _deletePayment(BuildContext context, String paymentId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final paymentData = await _getPaymentById(widget.storeId, paymentId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "delete_payment",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User menghapus metode pembayaran",
      meta: {"uid": user?.uid, "payment": paymentData},
    );
  }

  Future<void> _editPayment(BuildContext context, String paymentId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    final paymentData = await _getPaymentById(widget.storeId, paymentId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "edit_payment",
      name: name,
      role: widget.role,
      email: user?.email ?? "",
      desc: "User mengubah metode pembayaran",
      meta: {"uid": user?.uid, "payment": paymentData},
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
                  ],
                ),
              ),

              // BODY
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
                              "Payment Methods",
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
                                hintText: 'Search Payments...',
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
                                    .collection('stores')
                                    .doc(widget.storeId)
                                    .collection('payments')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  final docs = snapshot.data!.docs.where((doc) {
                                    final name = (doc['name'] ?? '').toLowerCase();
                                    return name.contains(_searchController.text.toLowerCase());
                                  }).toList();

                                  return ListView.builder(
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final payment = docs[index];
                                      final bool isSelected = _selectedPaymentId == payment.id;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedPaymentId = payment.id;
                                            _nameController.text = payment['name'] ?? '';
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
                                                payment['name'] ?? 'Unnamed',
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
                                                        title: const Text("Hapus Payment?"),
                                                        content: Text("Hapus metode pembayaran '${payment['name']}' ?"),
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
                                                        .collection('stores')
                                                        .doc(widget.storeId)
                                                        .collection('payments')
                                                        .doc(payment.id)
                                                        .delete();

                                                    await _deletePayment(context, payment.id);

                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text("Payment berhasil dihapus"),
                                                        ),
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

                    // RIGHT SIDE FORM
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: beige,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOGGLE
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _activeForm = 'add';
                                        _selectedPaymentId = null;
                                        _nameController.clear();
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
                                      if (_selectedPaymentId == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Pilih payment terlebih dahulu"),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() => _activeForm = 'edit');
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
                                  ? "Tambah Metode Pembayaran"
                                  : "Edit Metode Pembayaran",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 12),

                            const Text("Payment Name"),
                            TextField(controller: _nameController),

                            const SizedBox(height: 16),
                            const Text("Pilih Admin"),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: brown, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _getAdmins(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text("Loading admin...", style: TextStyle(color: Colors.brown)),
                                    );
                                  }

                                  final admins = snapshot.data!.docs;

                                  return DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedAdminId,
                                      hint: const Text(
                                        "Pilih Admin",
                                        style: TextStyle(color: Colors.brown),
                                      ),
                                      icon: const Icon(Icons.arrow_drop_down, color: Colors.brown),
                                      dropdownColor: Colors.white,
                                      style: const TextStyle(color: Colors.brown),
                                      items: admins.map((doc) {
                                        return DropdownMenuItem(
                                          value: doc.id,
                                          child: Text(
                                            doc['name'] ?? 'No Name',
                                            style: const TextStyle(color: Colors.brown),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedAdminId = value;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),

                            const Spacer(),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: Text(
                                  _activeForm == 'add'
                                      ? "Tambah Payment"
                                      : "Simpan Perubahan",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brown,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  if (_nameController.text.isEmpty) return;

                                  final ref = FirebaseFirestore.instance
                                      .collection('stores')
                                      .doc(widget.storeId)
                                      .collection('payments');

                                  final messenger = ScaffoldMessenger.of(context);

                                  if (_activeForm == 'add') {
                                    final newDoc = await ref.add({
                                      'name': _nameController.text,
                                      'adminId': _selectedAdminId,
                                    });

                                    await _addPayment(context, newDoc.id);
                                  } else if (_selectedPaymentId != null) {
                                    await ref.doc(_selectedPaymentId).update({
                                      'name': _nameController.text,
                                      'adminId': _selectedAdminId,
                                    });

                                    await _editPayment(context, _selectedPaymentId!);
                                  }

                                  if (!mounted) return;

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _activeForm == 'add'
                                            ? "Payment ditambahkan"
                                            : "Payment diperbarui",
                                      ),
                                    ),
                                  );

                                  _nameController.clear();
                                  _selectedPaymentId = null;

                                  setState(() => _activeForm = 'add');
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    )
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
