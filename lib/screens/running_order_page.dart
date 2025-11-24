import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/activity_logger.dart';
import '../widgets/sidebar_wrapper.dart';

class RunningOrderPage extends StatefulWidget {
  final String storeId;
  final String role;

  const RunningOrderPage({
    super.key,
    required this.storeId,
    required this.role,
  });

  @override
  State<RunningOrderPage> createState() => _RunningOrderPageState();
}

class _RunningOrderPageState extends State<RunningOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  Map<String, bool> expanded = {};

  Widget _noBounce({required Widget child}) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: child,
    );
  }

  // ---------------- HEADER ----------------
  Widget buildHeader() {
    return Container(
      color: Colors.white, // tidak ada border bawah lagi
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.account_circle, size: 32, color: Color(0xFF4B2E2B)),
          const SizedBox(width: 8),
          Text(
            "Hi, ${widget.role}",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B2E2B),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- UTILITIES ----------------
  String formatNumber(num x) {
    return x.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  String formatOrderType(String type) {
    switch (type) {
      case "dineIn":
        return "Dine In";
      case "takeAway":
        return "Take Away";
      case "delivery":
        return "Delivery";
      default:
        return type;
    }
  }

  Future<bool> _showConfirmDialog(
      BuildContext context, String title, String subtitle) async {
    return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(subtitle),
            actions: [
              TextButton(
                child: const Text("Tidak"),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: const Text("Ya"),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<Map<String, dynamic>> _getOrderById(
      String storeId, String orderId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('orders')
        .where('order_id', isEqualTo: orderId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return {"order_id": doc['order_id'], ...doc.data()};
    }

    return {};
  }

  Future<String> _getUserNameByEmail(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty
        ? snapshot.docs.first.data()['name'] ?? "Unknown"
        : "Unknown";
  }

  Future<String> _getRoleByEmail(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty
        ? snapshot.docs.first.data()['role'] ?? "Unknown"
        : "Unknown";
  }

  Future<void> _cancelOrder(BuildContext context, String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final role = await _getRoleByEmail(user?.email ?? "");
    final orderData = await _getOrderById(widget.storeId, orderId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "cancel_order",
      name: name,
      role: role,
      email: user?.email ?? "",
      desc: "Membatalkan Pesanan (Order)",
      meta: {"uid": user?.uid, "order": orderData},
    );
  }

  Future<void> _completeOrder(BuildContext context, String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final role = await _getRoleByEmail(user?.email ?? "");
    final orderData = await _getOrderById(widget.storeId, orderId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "complete_order",
      name: name,
      role: role,
      email: user?.email ?? "",
      desc: "Menyelesaikan Pesanan (Order)",
      meta: {"uid": user?.uid, "order": orderData},
    );
  }

  String formatTimestamp(dynamic ts) {
    if (ts is! Timestamp) return "-";
    final dt = ts.toDate();
    return "${dt.day.toString().padLeft(2, '0')}/"
        "${dt.month.toString().padLeft(2, '0')}/"
        "${dt.year.toString().substring(2)}, "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return SidebarWrapper(
  storeId: widget.storeId,
  role: widget.role,
  child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _noBounce(
          child: Column(
            children: [
              buildHeader(),

              Expanded(
                child: Container(
                  color: const Color(0xFFFDF2E1),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // TITLE LEFT
                      Row(
                        children: const [
                          Text(
                            "Orders Running List",
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xFF4B2E2B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('stores')
                              .doc(widget.storeId)
                              .collection('orders')
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final orders = snapshot.data!.docs;

                            if (orders.isEmpty) {
                              return const Center(
                                child: Text(
                                  "Tidak ada order berjalan.",
                                  style: TextStyle(color: Color(0xFF4B2E2B)),
                                ),
                              );
                            }

                            return ListView.builder(
                              physics: const ClampingScrollPhysics(),
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                final doc = orders[index];
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final id = doc.id;

                                expanded[id] = expanded[id] ?? false;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF4B2E2B),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Customer: ${data['customer_name']}",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF4B2E2B),
                                                  ),
                                                ),
                                                Text(
                                                  "Order Type: ${formatOrderType(data['type'])}",
                                                  style: const TextStyle(
                                                      color:
                                                          Color(0xFF4B2E2B)),
                                                ),
                                                if (data['type']
                                                    .toString()
                                                    .contains("dineIn"))
                                                  Text(
                                                    "Table: ${data['table']}",
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF4B2E2B)),
                                                  ),
                                                if (data['type']
                                                    .toString()
                                                    .contains("delivery"))
                                                  Text(
                                                    "Delivery: ${data['delivery']}",
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF4B2E2B)),
                                                  ),
                                                Text(
                                                  "Total: Rp ${formatNumber(data['total'])}",
                                                  style: const TextStyle(
                                                      color:
                                                          Color(0xFF4B2E2B)),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // CANCEL BUTTON
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              minimumSize:
                                                  const Size(70, 35),
                                            ),
                                            onPressed: isLoading
                                                ? null
                                                : () async {
                                                    setState(() =>
                                                        isLoading = true);

                                                    try {
                                                      final confirm =
                                                          await _showConfirmDialog(
                                                        context,
                                                        "Batalkan Pesanan?",
                                                        "Apakah Anda yakin ingin membatalkan pesanan ini?",
                                                      );

                                                      if (!confirm) return;

                                                      await _cancelOrder(
                                                          context,
                                                          data['order_id']);

                                                      await _firestore
                                                          .collection('stores')
                                                          .doc(widget.storeId)
                                                          .collection('orders')
                                                          .doc(id)
                                                          .update({
                                                        'status': 'cancelled'
                                                      });
                                                    } finally {
                                                      setState(() =>
                                                          isLoading = false);
                                                    }
                                                  },
                                            child: const Text(
                                              "Cancel",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // END BUTTON
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green,
                                              minimumSize:
                                                  const Size(70, 35),
                                            ),
                                            onPressed: isLoading
                                                ? null
                                                : () async {
                                                    setState(() =>
                                                        isLoading = true);

                                                    try {
                                                      final confirm =
                                                          await _showConfirmDialog(
                                                        context,
                                                        "Selesaikan Pesanan?",
                                                        "Apakah Anda yakin ingin mengakhiri pesanan ini?",
                                                      );

                                                      if (!confirm) return;

                                                      await _completeOrder(
                                                          context,
                                                          data['order_id']);

                                                      await _firestore
                                                          .collection('stores')
                                                          .doc(widget.storeId)
                                                          .collection('orders')
                                                          .doc(id)
                                                          .update({
                                                        'status': 'complete',
                                                        'endTime':
                                                            Timestamp.now(),
                                                      });
                                                    } finally {
                                                      setState(() =>
                                                          isLoading = false);
                                                    }
                                                  },
                                            child: const Text(
                                              "End",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // EXPAND BUTTON
                                          IconButton(
                                            icon: Icon(
                                              expanded[id] == true
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color:
                                                  const Color(0xFF4B2E2B),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                expanded[id] =
                                                    !(expanded[id] ?? false);
                                              });
                                            },
                                          ),
                                        ],
                                      ),

                                      // EXPANDED DETAIL
                                      if (expanded[id] == true) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Color(0xFF4B2E2B),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Detail Order:",
                                                style: TextStyle(
                                                  color: Color(0xFF4B2E2B),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 6),

                                              Text(
                                                "Order Id: ${data['order_id'] ?? '-'}",
                                                style: const TextStyle(
                                                    color:
                                                        Color(0xFF4B2E2B)),
                                              ),
                                              Text(
                                                "Time Place Order: ${formatTimestamp(data['created_at'])}",
                                                style: const TextStyle(
                                                    color:
                                                        Color(0xFF4B2E2B)),
                                              ),
                                              Text(
                                                "Payment: ${data['payment'] ?? '-'}",
                                                style: const TextStyle(
                                                    color:
                                                        Color(0xFF4B2E2B)),
                                              ),
                                              Text(
                                                "Cashier: ${data['cashier'] ?? '-'}",
                                                style: const TextStyle(
                                                    color:
                                                        Color(0xFF4B2E2B)),
                                              ),

                                              const SizedBox(height: 8),
                                              const Text(
                                                "Items:",
                                                style: TextStyle(
                                                  color: Color(0xFF4B2E2B),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              const SizedBox(height: 6),

                                              if (data['items'] != null)
                                                ...List.generate(
                                                  data['items'].length,
                                                  (i) {
                                                    final item =
                                                        data['items'][i];
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      margin:
                                                          const EdgeInsets.only(
                                                              bottom: 8),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: Color(
                                                              0xFF4B2E2B),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "- ${item['name']} x${item['qty']} (Rp ${formatNumber(item['price'])})",
                                                            style: const TextStyle(
                                                                color: Color(
                                                                    0xFF4B2E2B)),
                                                          ),
                                                          Text(
                                                            "- Category: ${item['category']}",
                                                            style: const TextStyle(
                                                                color: Color(
                                                                    0xFF4B2E2B)),
                                                          ),
                                                          Text(
                                                            "- Noted: ${item['noted'] ?? '-'}",
                                                            style: const TextStyle(
                                                                color: Color(
                                                                    0xFF4B2E2B)),
                                                          ),
                                                          Text(
                                                            "- Disc (%): ${item['disc'] ?? 0}",
                                                            style: const TextStyle(
                                                                color: Color(
                                                                    0xFF4B2E2B)),
                                                          ),
                                                          Text(
                                                            "- Disc Nominal: ${item['disc_nominal'] ?? 0}",
                                                            style: const TextStyle(
                                                                color: Color(
                                                                    0xFF4B2E2B)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),

                                              const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      ]
                                    ],
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
            ],
          ),
        ),
      ),
    ),
    );
  }
}
