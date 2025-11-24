import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/orders_page.dart';
import '../utils/activity_logger.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;


  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Login Firebase
      final authResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final email = authResult.user?.email;
      if (email == null) throw Exception("Email not found");

      // Ambil data user dari Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        Fluttertoast.showToast(msg: "User not found");
        return;
      }

      final userData = usersSnapshot.docs.first.data();
      final storeId = userData['storeId'];
      final name = userData['name'];
      final role = userData['role'];

      if (storeId == null || storeId.isEmpty) {
        Fluttertoast.showToast(msg: "No store linked to this user");
        return;
      }

      Fluttertoast.showToast(msg: "Login Successful");

      // LOG AKTIVITAS LOGIN
      await ActivityLogger.log(
        storeId: storeId,
        action: 'login',
        name: name ?? 'Unknown',
        role: role ?? 'Unknown',
        email: email,
        desc: 'User logged in',
        meta: {"loginTime": DateTime.now().toIso8601String(),
      },

      );

      // Pindah halaman
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderManagePage(storeId: storeId),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.brown, // warna fokus
          ),
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.brown, width: 2),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5E3C)), // coklat tua
            ),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5E3C)),
            ),
            hintStyle: TextStyle(color: Colors.brown.shade300),
          ),
        ),
        child: Scaffold(
        backgroundColor: const Color(0xFFFFFAF0),
        body: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA64D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome Admin\nFUNGIBITE",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.brown
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDECC8),
                    foregroundColor: Colors.brown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Submit"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
