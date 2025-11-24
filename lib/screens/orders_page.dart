import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/sidebar_wrapper.dart';
import '../utils/activity_logger.dart';

class OrderManagePage extends StatefulWidget {
  final String storeId;
  const OrderManagePage({super.key, required this.storeId});

  @override
  State<OrderManagePage> createState() => _OrderManagePageState();
}

enum OrderType { dineIn, takeAway, delivery }

class _OrderManagePageState extends State<OrderManagePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> cart = [];

  String formatNumber(num n) {
      if (n == n.toInt()) {
        return n.toInt().toString();
      }
      return n.toString();
    }

  OrderType? selectedType;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController tableController = TextEditingController();
  final TextEditingController orderIdController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  bool isPlacingOrder = false;
  bool isLoading = false;

  String formatOrderType(String raw) {
  if (raw.contains("dineIn")) return "Dine In";
  if (raw.contains("takeAway")) return "Take Away";
  if (raw.contains("delivery")) return "Delivery";
    return raw;
  }

  String? selectedDeliveryApp;
  String? selectedPayment;
  String? selectedCategory;
  String? userRole;

  Future<Map<String, dynamic>> _getOrderById(String storeId, String orderId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('orders')
        .where('order_id', isEqualTo: orderId) // <-- query berdasarkan field order_id
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return {
        "order_id": doc['order_id'], // ini field custom-mu
        ...doc.data(),
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

  Future<String> _getRoleByEmail(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['role'] ?? "Unknown";
    }

    return "Unknown";
  }

  Future<void> _placeorder(BuildContext context, String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");
    final role = await _getRoleByEmail(user?.email ?? "");

    final orderData = await _getOrderById(widget.storeId, orderId);

    await ActivityLogger.log(
      storeId: widget.storeId,
      action: "place_order",
      name: name,
      role: role,
      email: user?.email ?? "",
      desc: "Menambahkan Pesanan (Order)",
      meta: {
        "uid": user?.uid,
        "order": orderData,
      },
    );
  }

  double get totalPayable =>
    cart.fold(0, (total, item) {
      final discPercent = item['disc'] ?? 0;
      final discNominal = item['discNominal'] ?? 0;
      final rawTotal = item['price'] * item['qty'];
      final itemTotal = ((rawTotal * (1 - discPercent / 100)) - discNominal).clamp(0, double.infinity);
      return total + itemTotal;
    });

  double cashGiven = 0;
  String? cashError;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  Future<void> fetchUserRole() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final email = currentUser.email;
      if (email == null) return;

      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          userRole = data['role'] ?? 'User';
        });
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  void addToCart(Map<String, dynamic> menu, [String? size]) {
    setState(() {
      final selectedSize = size ?? 'No size';
      dynamic priceValue;

      if (menu['price'] is Map && size != null) {
        priceValue = menu['price'][size];
      } else {
        priceValue = menu['price'];
      }

      final price = (priceValue is num) ? priceValue.toDouble() : 0.0;

      final index = cart.indexWhere(
        (e) => e['name'] == menu['name'] && e['size'] == selectedSize,
      );

      if (index != -1) {
        cart[index]['qty'] += 1;
      } else {
        cart.add({
          'name': menu['name'],
          'category': menu['categories'],
          'size': selectedSize,
          'price': price,
          'qty': 1,
          'disc': 0,
          'discNominal': 0,
        });
      }
    });
  }

  Future<void> placeOrder() async {
  // Hindari double click
  if (isPlacingOrder) return;

  setState(() => isPlacingOrder = true);

  try {
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tolong pilih Order Type terlebih dahulu.')),
      );
      return;
    }

    if (selectedType == OrderType.dineIn) {
      if (nameController.text.isEmpty || tableController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tolong isi nama pemesan dan nomor meja terlebih dahulu.')),
        );
        return;
      }
    } else if (selectedType == OrderType.takeAway) {
      if (nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tolong isi nama pemesan terlebih dahulu.')),
        );
        return;
      }
    } else if (selectedType == OrderType.delivery) {
      if (nameController.text.isEmpty || orderIdController.text.isEmpty || selectedDeliveryApp == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tolong isi nama pemesan, ID pesanan, dan pilih delivery terlebih dahulu.')),
        );
        return;
      }
    }

    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong, tidak dapat melakukan order.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada kasir yang login.')),
      );
      return;
    }

    final email = currentUser.email;

    final userSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data kasir tidak ditemukan di Firestore.')),
      );
      return;
    }

    final userData = userSnapshot.docs.first.data();
    final cashierName = userData['username'] ?? 'Unknown Cashier';

    final now = DateTime.now();
    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    final orderCollection = _firestore
        .collection('stores')
        .doc(widget.storeId)
        .collection('orders');

    final todayOrdersSnapshot = await orderCollection
        .where('created_at', isGreaterThanOrEqualTo: DateTime(now.year, now.month, now.day))
        .where('created_at', isLessThan: DateTime(now.year, now.month, now.day + 1))
        .get();

    final orderNumber = todayOrdersSnapshot.docs.length + 1;

    String orderId = "";
    if (selectedType == OrderType.dineIn) {
      orderId = "FGB-DI-$dateStr-${orderNumber.toString().padLeft(2, '0')}";
    } else if (selectedType == OrderType.takeAway) {
      orderId = "FGB-TKW-$dateStr-${orderNumber.toString().padLeft(2, '0')}";
    } else if (selectedType == OrderType.delivery) {
      final deliveryAppCode = selectedDeliveryApp?.substring(0, 3).toUpperCase() ?? "DLV";
      orderId = "FGB-DLV-$deliveryAppCode-$dateStr-${orderNumber.toString().padLeft(2, '0')}";
    }


    Map<String, dynamic> orderData = {
      'order_id': orderId,
      'items': cart,
      'total': totalPayable,
      'created_at': FieldValue.serverTimestamp(),
      'status': 'pending',
      'type': selectedType.toString(),
      'customer_name': nameController.text,
      'cashier': cashierName,
      'payment': selectedPayment ?? 'Unspecified',
    };

    if (selectedType == OrderType.dineIn) {
      orderData['table'] = tableController.text;
    } else if (selectedType == OrderType.delivery) {
      orderData['delivery_app'] = selectedDeliveryApp;
    }

    await orderCollection.add(orderData);
    await _placeorder(context, orderId);

    setState(() {
      cart.clear();
      nameController.clear();
      tableController.clear();
      orderIdController.clear();
      selectedDeliveryApp = null;
      selectedPayment = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order placed successfully! ID: $orderId')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error placing order: $e')),
    );
  } finally {
    setState(() => isPlacingOrder = false);
  }
}

  Stream<QuerySnapshot> getFilteredMenus() {
    Query query = _firestore
        .collection('stores')
        .doc(widget.storeId)
        .collection('menus');

    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      query = query.where('categories', arrayContains: selectedCategory);
    }

    return query.snapshots();
  }

  bool showDineInForm = false;
  bool showTakeAwayForm = false;
  bool showDeliveryForm = false;



  @override
  Widget build(BuildContext context) {
    return SidebarWrapper(
      storeId: widget.storeId,
      role: userRole ?? "Casier",
      child: Scaffold(
        backgroundColor: const Color(0xFFFFEBD3),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.account_circle,
                            size: 32, color: Colors.brown),
                        const SizedBox(width: 8),
                        Text(
                          "Hi, ${userRole ?? '...'}",
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(
                            color: const Color(0xFFFDF2E1),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                  const SizedBox(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _tabButtonToggle("Dine In", OrderType.dineIn, () {
                                      setState(() {
                                        showDineInForm = true;
                                        showTakeAwayForm = false;
                                        showDeliveryForm = false;
                                        selectedType = OrderType.dineIn;
                                      });
                                    }),

                                    _tabButtonToggle("Take Away", OrderType.takeAway, () {
                                      setState(() {
                                        showDineInForm = false;
                                        showTakeAwayForm = true;
                                        showDeliveryForm = false;
                                        selectedType = OrderType.takeAway;
                                      });
                                    }),

                                    _tabButtonToggle("Delivery", OrderType.delivery, () {
                                      setState(() {
                                        showDineInForm = false;
                                        showTakeAwayForm = false;
                                        showDeliveryForm = true;
                                        selectedType = OrderType.delivery;
                                      });
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (showDineInForm || showTakeAwayForm || showDeliveryForm)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        // ...existing code...
                                        if (showDineInForm && selectedType == OrderType.dineIn)
                                          Row(
                                            children: [
                                              
                                              // KOTAK NAMA (KIRI)
                                              Expanded(
  child: SizedBox(
    height: 40,
    child: TextField(
      controller: nameController,
      style: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
      decoration: InputDecoration(
        labelText: 'Nama Pemesan',
        labelStyle: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ),
),

const SizedBox(width: 14),

// NOMOR MEJA
Expanded(
  child: SizedBox(
    height: 40,
    child: TextField(
      controller: tableController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
      decoration: InputDecoration(
        labelText: 'Nomor Meja',
        labelStyle: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ),
),

const SizedBox(width: 12),

// PAYMENT (dropdown)
Expanded(
  child: SizedBox(
    height: 40,
    child: StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('payments')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedPayment,
          iconEnabledColor: const Color(0xFF4B2E2B),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
          decoration: InputDecoration(
            labelText: 'Payment',
            labelStyle: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 2,
              ),
            ),
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: data['name'],
              child: Text(
                data['name'],
                style: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => selectedPayment = val);
          },
        );
      },
    ),
  ),
),
                                            ]
                                          )
                                          else if (showTakeAwayForm && selectedType == OrderType.takeAway)
                                          // Take Away — kotak nama + payment
                                          Row(
                                            children: [
                                              Expanded(
  child: SizedBox(
    height: 40,
    child: TextField(
      controller: nameController,
      style: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
      decoration: InputDecoration(
        labelText: 'Nama Pemesan',
        labelStyle: const TextStyle(color: Color(0xFF4B2E2B), fontSize: 12),
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ),
),
                                              const SizedBox(width: 12),
                                              Expanded(
  child: SizedBox(
    height: 40,
    child: StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('payments')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedPayment,
          iconEnabledColor: const Color(0xFF4B2E2B),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF4B2E2B),
            fontSize: 12,
          ),
          decoration: InputDecoration(
            labelText: 'Payment',
            labelStyle: const TextStyle(
              color: Color(0xFF4B2E2B),
              fontSize: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: data['name'],
              child: Text(
                data['name'],
                style: const TextStyle(
                  color: Color(0xFF4B2E2B),
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => selectedPayment = val);
          },
        );
      },
    ),
  ),
),
                                            ],
                                          ),
                                          if (showDeliveryForm && selectedType == OrderType.delivery) ...[
                                          Row(
                                            children: [
                                              // Nama Pemesan
                                              // NAMA PEMESAN
Expanded(
  child: SizedBox(
    height: 40,
    child: TextField(
      controller: nameController,
      style: const TextStyle(
        color: Color(0xFF4B2E2B),
        fontSize: 12,
      ),
      decoration: InputDecoration(
        labelText: 'Nama Pemesan',
        labelStyle: const TextStyle(
          color: Color(0xFF4B2E2B),
          fontSize: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ),
),

const SizedBox(width: 12),

// ID PESANAN
Expanded(
  child: SizedBox(
    height: 40,
    child: TextField(
      controller: orderIdController,
      style: const TextStyle(
        color: Color(0xFF4B2E2B),
        fontSize: 12,
      ),
      decoration: InputDecoration(
        labelText: 'ID Pesanan',
        labelStyle: const TextStyle(
          color: Color(0xFF4B2E2B),
          fontSize: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4B2E2B),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ),
),

const SizedBox(width: 12),

// DROPDOWN DELIVERY
Expanded(
  child: SizedBox(
    height: 40,
    child: StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('deliveries')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedDeliveryApp,
          iconEnabledColor: const Color(0xFF4B2E2B),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF4B2E2B),
            fontSize: 12,
          ),
          decoration: InputDecoration(
            labelText: 'Delivery',
            labelStyle: const TextStyle(
              color: Color(0xFF4B2E2B),
              fontSize: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: data['name'],
              child: Text(
                data['name'],
                style: const TextStyle(
                  color: Color(0xFF4B2E2B),
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => selectedDeliveryApp = val);
          },
        );
      },
    ),
  ),
),

const SizedBox(width: 12),

// PAYMENT
Expanded(
  child: SizedBox(
    height: 40,
    child: StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('payments')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedPayment,
          iconEnabledColor: const Color(0xFF4B2E2B),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF4B2E2B),
            fontSize: 12,
          ),
          decoration: InputDecoration(
            labelText: 'Payment',
            labelStyle: const TextStyle(
              color: Color(0xFF4B2E2B),
              fontSize: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4B2E2B),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: data['name'],
              child: Text(
                data['name'],
                style: const TextStyle(
                  color: Color(0xFF4B2E2B),
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => selectedPayment = val);
          },
        );
      },
    ),
  ),
),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                _buildCartSection(),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _buildMenuSection(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
  return Expanded(
    child: Column(
      children: [
        // HEADER
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                  child: Text("Item",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text("Size",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text("Price",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text("Qty",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text("Disc%",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text("Disc Nominal",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text("Total",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.black45),

        // LIST ITEM
        Expanded(
          child: ListView.builder(
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final item = cart[index];

              // Pastikan ada field discNominal
              item['discNominal'] = item['discNominal'] ?? 0;
              item['disc'] = item['disc'] ?? 0;

              final discPercent = item['disc'] ?? 0;
              final discNominal = item['discNominal'] ?? 0;
              final rawTotal = item['price'] * item['qty'];
              final itemTotal =
                  ((rawTotal * (1 - discPercent / 100)) - discNominal)
                      .clamp(0, double.infinity);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SIDE: NAME + NOTE
                    SizedBox(
                      width: 73,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),

                          // NOTED BUTTON
                          InkWell(
                            onTap: () async {
                              final note = await showDialog(
                                context: context,
                                builder: (context) {
                                  TextEditingController noteController =
                                      TextEditingController(
                                          text: item['noted'] ?? '');
                                  return AlertDialog(
                                    title: const Text("Add Note"),
                                    content: TextField(
                                      controller: noteController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        hintText: "Tuliskan catatan...",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("Cancel")),
                                      ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(
                                                context, noteController.text);
                                          },
                                          child: const Text("Save")),
                                    ],
                                  );
                                },
                              );
                              if (note != null) {
                                setState(() {
                                  item['noted'] = note;
                                });
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.edit,
                                    size: 14, color: Colors.brown),
                                SizedBox(width: 4),
                                Text("Noted", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),

                          // SHOW NOTE IF EXISTS
                          if ((item['noted'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item['noted'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // SIZE
                    Expanded(
                      child: Text(
                        item['size'],
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // PRICE
                    Expanded(
                      child: Text(
                        "${formatNumber(item['price'])}",
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // QTY
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (item['qty'] > 1) {
                                  item['qty']--;
                                } else {
                                  cart.removeAt(index);
                                }
                              });
                            },
                            child: const Icon(Icons.remove,
                                size: 16, color: Colors.red),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(item['qty'].toString()),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                item['qty']++;
                              });
                            },
                            child: const Icon(Icons.add,
                                size: 16, color: Colors.green),
                          ),
                        ],
                      ),
                    ),

                    // DISC %
                    Expanded(
                      child: SizedBox(
                        height: 20,
                        child: TextFormField(
                          initialValue: item['disc'].toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, height: 1.0),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            setState(() {
                              item['disc'] = double.tryParse(value) ?? 0;
                            });
                          },
                        ),
                      ),
                    ),

                    // DISC NOMINAL
                    Expanded(
                      child: SizedBox(
                        height: 20,
                        child: TextFormField(
                          initialValue: item['discNominal'].toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, height: 1.0),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            setState(() {
                              item['discNominal'] = double.tryParse(value) ?? 0;
                            });
                          },
                        ),
                      ),
                    ),

                    // TOTAL
                    Expanded(
                      child: Text(
                        itemTotal.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // ---- Input Tunai ----
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 45,
                    child: TextField(
                      enabled: selectedPayment == "Cash",
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "Tunai",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                        errorText: cashError,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onChanged: (value) {
                        final amount = double.tryParse(value) ?? 0;
                        setState(() {
                          cashGiven = amount;
                          cashError = amount < totalPayable
                              ? "Anda tidak boleh memasukkan kurang dari harga total"
                              : null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ---- Total Payable ----
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 45,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Total Payable",
                        labelStyle: TextStyle(
                          color: totalPayable > 0 ? Colors.grey[700] : Colors.black.withOpacity(0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      child: Text(
                        totalPayable > 0 ? "Rp ${totalPayable.toStringAsFixed(0)}" : "",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ---- Kembalian ----
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 45,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Kembalian",
                        labelStyle: TextStyle(
                          color: (selectedPayment == "Cash" && cashGiven > 0 && cashGiven >= totalPayable)
                              ? Colors.grey[700]
                              : Colors.black.withOpacity(0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      child: Text(
                        (selectedPayment == "Cash" && cashGiven > 0 && cashGiven >= totalPayable)
                            ? "Rp ${formatNumber((cashGiven - totalPayable).clamp(0, double.infinity))}"
                            : "",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bottomButton("Delete", Colors.red, () async {
              setState(() => cart.clear());
            }),
            const SizedBox(width: 8),
            _bottomButton("Place Order", Colors.green, placeOrder),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildMenuSection() {
    return Container(
      color: const Color(0xFFFFD08E),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Cari menu...",
                    hintStyle: const TextStyle(color: Colors.white),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF4B2E2B), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF4B2E2B), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('stores')
                    .doc(widget.storeId)
                    .collection('categories')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                        width: 120,
                        child: Center(child: CircularProgressIndicator()));
                  }

                  final categories = snapshot.data!.docs;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border.all(color: Color(0xFF4B2E2B), width: 2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      hint: const Text("Kategori", style: TextStyle(color: Colors.white)),
                      dropdownColor: const Color(0xFF4B2E2B), // menu dropdown
                      underline: const SizedBox(), // hilangkan garis default
                      iconEnabledColor: Colors.white,

                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("Semua", style: TextStyle(color: Colors.white)),
                        ),
                        ...categories.map((cat) {
                          final data = cat.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: data['name'],
                            child: Text(data['name'],
                                style: const TextStyle(color: Colors.white)),
                          );
                        }),
                      ],

                      onChanged: (val) {
                        setState(() => selectedCategory = val);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getFilteredMenus(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMenus = snapshot.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();

                final filteredMenus = allMenus.where((menu) {
                  final name =
                      (menu['name'] ?? '').toString().toLowerCase();
                  final query =
                      searchController.text.toLowerCase().trim();
                  return name.contains(query);
                }).toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return ListView.builder(
                      itemCount: filteredMenus.length,
                      itemBuilder: (context, index) {
                        final menu = filteredMenus[index];
                        final hasSizes = menu.containsKey('sizes') &&
                            menu['sizes'] != "No size";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // NAMA MENU
                              Expanded(
                                child: Text(
                                  menu['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // BUTTON SIZE DI KANAN
                              hasSizes
                                  ? Row(
                                      children: (menu['sizes'] as List<dynamic>).map((size) {
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                addToCart(menu, size.toString()),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4B2E2B),
                                              minimumSize: const Size(50, 36),
                                            ),
                                            child: Text(
                                              size.toString(),
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => addToCart(menu),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4B2E2B),
                                        minimumSize: const Size(60, 36),
                                      ),
                                      child: const Text(
                                        "Add",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButtonToggle(String label, OrderType type, VoidCallback onTap) {
    bool isOpen = false;
    if (type == OrderType.dineIn) isOpen = showDineInForm;
    if (type == OrderType.takeAway) isOpen = showTakeAwayForm;
    if (type == OrderType.delivery) isOpen = showDeliveryForm;

    return Expanded(
      child: SizedBox(
        height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
           backgroundColor: isOpen ? const Color(0xFF4B2E2B) : Colors.transparent,
            side: const BorderSide(color: Color(0xFF4B2E2B), width: 2),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isOpen ? Colors.white : const Color(0xFF4B2E2B),
              fontWeight: FontWeight.bold, fontSize: 12,
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _bottomButton(String text, Color color, Future<void> Function() onPressed) {
    return Expanded( // supaya tombol melebar sesuai Row
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(0, 30), // tinggi 50, lebar diatur oleh Expanded
        ),
        onPressed: isLoading ? null : () async {
          setState(() => isLoading = true);
          try {
            await onPressed();
          } finally {
            setState(() => isLoading = false);
          }
        },
        child: isLoading
            ? const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  color: Colors.brown, // loading coklat
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white, // text putih
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}
