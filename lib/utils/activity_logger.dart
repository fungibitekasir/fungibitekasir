import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogger {
  static Future<void> log({
    required String storeId,
    required String action,
    required String name,
    required String role,
    required String email,
    required String desc,
    required Map<String, dynamic> meta,
  }) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('activities');

      final now = DateTime.now().toIso8601String();

      final doc = {
        'timestamp': FieldValue.serverTimestamp(),
        'datetime': now, // aman di desktop
        'action': action,
        'name': name,
        'role': role,
        'email': email,
        'desc': desc,
        'meta': meta,
      };

      await ref.add(doc);
    } catch (e) {
      // Mencegah crash di Windows & mencatat error
      print("ActivityLogger ERROR: $e");
    }
  }
}
