import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> pushToSheet(Map<String, dynamic> data) async {
  final url = Uri.parse(
      'https://script.google.com/macros/s/AKfycbyRkEa1wv7Thp_9L0P7USgajLd2SMAPHyMlMlpqK3_98u7fOmY7w0eCMn8UMDrflol4/exec'); // ganti dengan URL Web App mu

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print('Web: berhasil push data: ${response.body}');
    } else {
      print('Web: gagal push data: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    print('Web: error push data: $e');
  }
}
