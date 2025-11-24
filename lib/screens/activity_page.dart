import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_wrapper.dart';

class ActivityPage extends StatefulWidget {
  final String storeId;
  final String role;
  const ActivityPage({super.key, required this.storeId, required this.role});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  void _showDetailDialog(BuildContext context, Map<String, dynamic> data) {
    final order = data["meta"]?["order"] ?? {};
    final category = data["meta"]?["category"] ?? {};
    final size = data["meta"]?["size"] ?? {};
    final admin = data["meta"]?["admin"] ?? {};
    final delivery = data["meta"]?["delivery"] ?? {};
    final payment = data["meta"]?["payment"] ?? {};
    final menu = data["meta"]?["menu"] ?? {};


    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Activity Details",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailText("Action", data["action"]),
                  _detailText("Time", data["datetime"]),
                  _detailText("Name", data["name"]),
                  _detailText("Role", data["role"]),
                  _detailText("Email", data["email"]),
                  _detailText("Description", data["desc"]),
                  const Divider(height: 32),

                  const Text(
                    "Order Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (order.isEmpty)
                    const Text("No order data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Order ID", order["order_id"]),
                    _detailText("Status", order["status"]),
                    _detailText("Customer", order["customer_name"]),
                    _detailText("Cashier", order["cashier"]),
                    _detailText("Type", order["type"]),
                    _detailText("Total", order["total"].toString()),

                    const SizedBox(height: 8),
                    const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),

                    ...((order["items"] as List?) ?? []).map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text("- ${item["name"]} x${item["qty"]}"),
                      );
                    }).toList(),
                  ],
                  // === CATEGORY DETAILS ===
                  const SizedBox(height: 20),
                  const Text(
                    "Category Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (category.isEmpty)
                    const Text("No category data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Name", category["name"]),
                    _detailText("Admin", category["admin"]),
                  ],

                  // === SIZE DETAILS ===
                  const SizedBox(height: 20),
                  const Text(
                    "Size Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (size.isEmpty)
                    const Text("No size data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Name", size["name"]),
                    _detailText("Admin", size["admin"]),
                  ],

                  // === PAYMENT DETAILS ===
                  const SizedBox(height: 20),
                  const Text(
                    "Payment Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (payment.isEmpty)
                    const Text("No payment data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Name", payment["name"]),
                    _detailText("Admin", payment["admin"]),
                  ],

                  // === DELIVERY DETAILS ===
                  const SizedBox(height: 20),
                  const Text(
                    "Delivery Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (delivery.isEmpty)
                    const Text("No delivery data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Name", delivery["name"]),
                    _detailText("Admin", delivery["admin"]),
                  ],
                  // === ADMIN DETAILS ===
                  const SizedBox(height: 20),
                  const Text(
                    "Admin Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (admin.isEmpty)
                    const Text("No admin data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Username", admin["username"]),
                    _detailText("Name", admin["name"]),
                    _detailText("Admin", admin["admin"]),     // kalau kamu simpan field ini
                    _detailText("Role", admin["role"]),
                    _detailText("Email", admin["email"]),
                  ],
                  // === MENU DETAILS ===
                  const SizedBox(height: 20),
                  const Text(
                    "Menu Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (menu.isEmpty)
                    const Text("No menu data.", style: TextStyle(color: Colors.grey))
                  else ...[
                    _detailText("Admin Name", menu["name"]),
                    _detailText("Name", menu["name"]),

                    // === Categories (ARRAY) ===
                    const SizedBox(height: 8),
                    const Text("Categories:", style: TextStyle(fontWeight: FontWeight.bold)),
                    if ((menu["categories"] as List?)?.isEmpty ?? true)
                      const Text("- No categories -")
                    else
                      ...((menu["categories"] as List).map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text("- $c"),
                          ))),

                    const SizedBox(height: 12),

                    // === Size (MAP) ===
                    const Text("Size:", style: TextStyle(fontWeight: FontWeight.bold)),
                    if (menu["size"] is Map)
                      ...[
                        _detailText("ID", menu["size"]["id"]),
                        _detailText("Label", menu["size"]["label"]),
                      ]
                    else
                      const Text("No size data."),

                    const SizedBox(height: 12),

                    // === Price (MAP mengikuti size) ===
                    const Text("Prices:", style: TextStyle(fontWeight: FontWeight.bold)),
                    if (menu["price"] is Map)
                      ...menu["price"].entries.map((entry) {
                        return Text("- ${entry.key}: Rp ${entry.value}");
                      })
                    else
                      const Text("No price data."),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Close"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _detailText(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: "$title: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value?.toString() ?? "-"),
          ],
        ),
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  final DateFormat _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  int _currentPage = 1;
  final int _perPage = 10;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _matchesQuery(Map<String, dynamic> data, String q) {
    if (q.isEmpty) return true;
    q = q.toLowerCase();
    final list = [
      data['action'] ?? '',
      data['name'] ?? '',
      data['role'] ?? '',
      data['email'] ?? '',
      data['desc'] ?? '',
    ];
    return list.any((e) => e.toString().toLowerCase().contains(q));
  }

  String _formatTimestamp(dynamic ts, String fallback) {
    try {
      if (ts == null) return fallback;
      if (ts is Timestamp) return _fmt.format(ts.toDate());
      if (ts is String) return ts;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Widget _header() {
    return Row(
      children: const [
        Expanded(flex: 2, child: Text("Date/Time", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 1, child: Text("Role", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 1, child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 4, child: Text("Description", style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Future<void> _pickDateRange() async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    initialDateRange: _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null,
    builder: (context, child) {
      return Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: child,
        ),
      );
    },
  );

  if (picked != null) {
    setState(() {
      _startDate = picked.start;
      _endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23, 59, 59,
      );
      _currentPage = 1;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return SidebarWrapper(
      storeId: widget.storeId,
      role: widget.role,
      child: Scaffold(
        backgroundColor: Colors.white,
        // Ganti bagian body: SafeArea(...) menjadi seperti ini
        body: SafeArea(
          child: Column(
            children: [
              // Header atas
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

              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.shade200.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Cari..",
                            filled: true,
                            fillColor: const Color(0xFFFFD9B0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.brown.shade800, // coklat tua
                                width: 1.5, // tebal garis
                              ),
                            ),
                            enabledBorder: OutlineInputBorder( // border saat tidak fokus
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.brown.shade800,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder( // border saat fokus
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.brown.shade900,
                                width: 2, // lebih tebal saat fokus
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),

                        // Filter tanggal
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.date_range),
                              label: const Text("Filter Date"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_startDate != null)
                              Text(
                                "${DateFormat('yyyy-MM-dd').format(_startDate!)} → ${DateFormat('yyyy-MM-dd').format(_endDate!)}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            if (_startDate != null)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                    _currentPage = 1;
                                  });
                                },
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // List Header (tetap di luar Container jika mau tetap sticky)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: _header(),
                        ),

                        const Divider(),

                        // List Aktivitas
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: stream,
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final q = _searchController.text.trim().toLowerCase();

                              var docs = snap.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final ts = data['timestamp'];

                                // ==== FILTER SEARCH ====
                                if (!_matchesQuery(data, q)) return false;

                                // ==== FILTER DATE ====
                                if (_startDate != null && _endDate != null) {
                                  DateTime dateTime;

                                  if (ts is Timestamp) {
                                    dateTime = ts.toDate();
                                  } else if (ts is String) {
                                    dateTime = DateTime.tryParse(ts) ?? DateTime.now();
                                  } else {
                                    return true;
                                  }

                                  if (dateTime.isBefore(_startDate!) || dateTime.isAfter(_endDate!)) {
                                    return false;
                                  }
                                }

                                return true;
                              }).toList();
                              if (docs.isEmpty) {
                                return const Center(child: Text("No activities found."));
                              }

                              final totalPages = (docs.length / _perPage).ceil();
                              final startIndex = (_currentPage - 1) * _perPage;
                              final endIndex = (_currentPage * _perPage);
                              final pageDocs = docs.sublist(
                                startIndex,
                                endIndex > docs.length ? docs.length : endIndex,
                              );

                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      itemBuilder: (_, i) {
                                        final d = pageDocs[i].data() as Map<String, dynamic>;
                                        final ts = d['timestamp'];
                                        final dt = _formatTimestamp(ts, d['datetime'] ?? 'Unknown');

                                        return GestureDetector(
                                          onTap: () {
                                            final data = d;
                                            _showDetailDialog(context, data);
                                          },
                                          child: Row(
                                            children: [
                                              Expanded(flex: 2, child: Text(dt)),
                                              Expanded(flex: 1, child: Text(d['role'] ?? '')),
                                              Expanded(flex: 1, child: Text(d['name'] ?? '')),
                                              Expanded(flex: 2, child: Text(d['action'] ?? '')),
                                              Expanded(flex: 2, child: Text(d['email'] ?? '')),
                                              Expanded(
                                                flex: 4,
                                                child: Text(
                                                  d['desc'] ?? '',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      separatorBuilder: (_, __) => const Divider(),
                                      itemCount: pageDocs.length,
                                    ),
                                  ),

                                  // Pagination
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                                        icon: const Icon(Icons.arrow_back),
                                      ),
                                      ..._buildPaginationNumbers(totalPages),
                                      IconButton(
                                        onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                                        icon: const Icon(Icons.arrow_forward),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  List<Widget> _buildPaginationNumbers(int totalPages) {
    int maxButtons = 3; // Maksimal tombol halaman yang muncul
    List<Widget> buttons = [];

    int startPage = _currentPage;
    int endPage = _currentPage + maxButtons - 1;

    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - maxButtons + 1).clamp(1, totalPages);
    }

    if (startPage > 1) {
      buttons.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text("..."),
      ));
    }

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => setState(() => _currentPage = i),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: i == _currentPage ? Colors.brown : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "$i",
              style: TextStyle(
                color: i == _currentPage ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ));
    }

    if (endPage < totalPages) {
      buttons.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text("..."),
      ));
    }

    return buttons;
  }
}
