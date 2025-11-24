import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/orders_page.dart';
import '../screens/daily_report_page.dart';
import '../screens/activity_page.dart';
import '../screens/menu_list_page.dart';
import '../screens/admin_list_page.dart';
import '../screens/categories_list_page.dart';
import '../screens/payment_page.dart';
import '../screens/size_list_page.dart';
import '../screens/login_page.dart';
import '../screens/delivery_list.dart';
import '../utils/activity_logger.dart';
import '../screens/running_order_page.dart';


class CombinedSidebar extends StatelessWidget {
  final String storeId;
  final String role;
  final VoidCallback onClose;

  const CombinedSidebar({
    super.key,
    required this.storeId,
    required this.role,
    required this.onClose,
  });

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

  Future<void> _logout(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = await _getUserNameByEmail(user?.email ?? "");

    await ActivityLogger.log(
      storeId: storeId,
      action: "logout",
      name: name,
      role: role,
      email: user?.email ?? "",
      desc: "User melakukan logout.",
      meta: {"uid": user?.uid},
    );

    await FirebaseAuth.instance.signOut();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Apakah Anda yakin ingin logout?"),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: const Color(0xFFFDECC8), // coklat muda
          border: Border(
            right: BorderSide(
              color: const Color(0xFF8B5E3C), // garis pinggir coklat tua
              width: 2,
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 10),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Fungibite",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildItem(context, "Order", OrderManagePage(storeId: storeId)),
            _buildItem(context, "Running Orders", RunningOrderPage(storeId: storeId, role: role)),
            _buildItem(context, "Daily Report", DailyReportPage(storeId: storeId)),
            ExpansionTile(
              title: const Text(
                "Add/Edit",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                _buildItem(context, "Menus", MenuManagerPage(storeId: storeId, role: role)),
                if (role == "Owner")
                  _buildItem(context, "Admin", AdminManagerPage(storeId: storeId, role: role)),
                _buildItem(context, "Categories", CategoriesManagerPage(storeId: storeId, role: role)),
                _buildItem(context, "Sizes", SizesManagerPage(storeId: storeId, role: role)),
                _buildItem(context, "Deliveries", DeliveriesManagerPage(storeId: storeId, role: role)),
                _buildItem(context, "Payments", PaymentsManagerPage(storeId: storeId, role: role)),
              ],
            ),
            if (role == "Owner")
              _buildItem(context, "Activity", ActivityPage(storeId: storeId, role: role)),
            const Divider(),
            ListTile(
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, String title, Widget page) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () {
        onClose();
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
