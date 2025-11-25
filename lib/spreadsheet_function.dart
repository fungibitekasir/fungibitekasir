import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> pushToSheet(Map<String, dynamic> data) async {
  const String webAppUrl = "https://script.google.com/macros/s/AKfycbyRkEa1wv7Thp_9L0P7USgajLd2SMAPHyMlMlpqK3_98u7fOmY7w0eCMn8UMDrflol4/exec"; // ganti sesuai Apps Script

  try {
    final response = await http.post(
      Uri.parse(webAppUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        print("Berhasil push ke Google Sheet");
      } else {
        print("Gagal push: ${result['message']}");
      }
    } else {
      print("HTTP error: ${response.statusCode}");
    }
  } catch (e) {
    print("Exception: $e");
  }
}
