import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/sidebar_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import '../utils/download_excel.dart';
import 'package:flutter/foundation.dart';
import '../utils/download_excel_mobile.dart';
import '../utils/download_excel_web.dart';


class DailyReportPage extends StatefulWidget {
  final String storeId;
  const DailyReportPage({super.key, required this.storeId});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  String selectedStatus = "All";
  List<String> statusOptions = ["All", "Complete", "Cancelled"];

  int rowsPerPage = 8;
  int currentPage = 1;

  DateTime? _startDate;
  DateTime? _endDate;

  void _showOrderDetail(Map<String, dynamic> data) {
  DateTime? createdAt;
  final createdRaw = data['created_at'];
  if (createdRaw is Timestamp) {
    createdAt = createdRaw.toDate();
  } else if (createdRaw is String) {
    createdAt = DateTime.tryParse(createdRaw);
  }

  DateTime? endTime;
  final endRaw = data['endTime'];
  if (endRaw is Timestamp) {
    endTime = endRaw.toDate();
  } else if (endRaw is String) {
    endTime = DateTime.tryParse(endRaw);
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // TITLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Order Detail",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _detailRow("Order ID", data['order_id']),
                _detailRow("Customer Name", data['customer_name']),
                _detailRow("Cashier", data['cashier']),
                _detailRow("Order Type", data['type']),
                _detailRow("Status", data['status']),
                _detailRow("Table", data['table']),
                _detailRow("Payment", data['payment'] ?? "-"),

                _detailRow(
                  "Created At",
                  createdAt != null
                      ? DateFormat('d/M/yyyy, HH.mm').format(createdAt)
                      : "-",
                ),
                _detailRow(
                  "End Time",
                  endTime != null
                      ? DateFormat('d/M/yyyy, HH.mm').format(endTime)
                      : "-",
                ),

                _detailRow("Total", "Rp ${data['total']}"),

                const SizedBox(height: 20),
                const Text(
                  "Items",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),

                ...((data['items'] as List?) ?? []).map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itemMap['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        _detailRow("Category", itemMap['category']?.toString() ?? '-'),
                        _detailRow("Qty", itemMap['qty'].toString()),
                        _detailRow("Price", "Rp. ${itemMap['price']}"),
                        _detailRow("Size", itemMap['size'].toString()),
                        _detailRow("Disc (%)", itemMap['disc'].toString()),
                        _detailRow("Disc Nominal", itemMap['discNominal'].toString()),
                        _detailRow("Note", itemMap['noted'] ?? "-"),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _showCategoryDetail(String categoryName, List<QueryDocumentSnapshot> filteredDocs) {
  // Hitung menu per category
  Map<String, int> menuInCategory = {};
  
  for (var doc in filteredDocs) {
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    
    for (var item in items) {
      final itemMap = item as Map<String, dynamic>;
      final categories = itemMap['category'] as List<dynamic>?;
      final cat = categories != null && categories.isNotEmpty
          ? categories.first.toString()
          : "Uncategorized";
      
      if (cat == categoryName) {
        final menuName = itemMap['name']?.toString() ?? 'Unknown';
        final qty = (itemMap['qty'] ?? 1) as int;
        menuInCategory[menuName] = (menuInCategory[menuName] ?? 0) + qty;
      }
    }
  }

  // Siapkan data untuk pie chart
  final sortedMenus = menuInCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  final colors = [
    Colors.red.shade700,
    Colors.blue.shade700,
    Colors.green.shade700,
    Colors.orange.shade700,
    Colors.purple.shade700,
    Colors.teal.shade700,
    Colors.pink.shade700,
    Colors.indigo.shade700,
  ];

  final pieData = sortedMenus.asMap().entries.map((entry) {
    final index = entry.key;
    final menu = entry.value;
    return PieChartSectionData(
      color: colors[index % colors.length],
      value: menu.value.toDouble(),
      title: '${menu.value}',
      radius: 80,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }).toList();

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Menu in $categoryName",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pie Chart
              SizedBox(
                height: 250,
                child: pieData.isEmpty
                    ? const Center(child: Text("No data available"))
                    : PieChart(
                        PieChartData(
                          sections: pieData,
                          centerSpaceRadius: 0,
                          sectionsSpace: 2,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
              ),
              
              const SizedBox(height: 24),

              // Legend
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: sortedMenus.asMap().entries.map((entry) {
                  final index = entry.key;
                  final menu = entry.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${menu.key} (${menu.value})",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _detailRow(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value?.toString() ?? '-'),
        ),
      ],
    ),
  );
}

  List<QueryDocumentSnapshot> getPagedData(List<QueryDocumentSnapshot> docs) {
    int start = (currentPage - 1) * rowsPerPage;
    int end = start + rowsPerPage;
    if (start > docs.length) return [];
    if (end > docs.length) end = docs.length;
    return docs.sublist(start, end);
  }

  Future<List<String>> getCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('categories')
        .get();

    return snapshot.docs
        .map((e) => e.data()['name']?.toString() ?? '-')
        .toList();
  }

    Future<void> downloadDailyReportExcel(
      String storeId,
      DateTime startDate,
      DateTime endDate,
      String selectedStatus,
    ) async {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('orders')
          .get();
      final allDocs = snapshot.docs;

      // PREPARE EXCEL
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      
      // ========== SHEET 1: RAW DATA ==========
      final sheet = excel['Daily Report'];

      // HEADER
      sheet.appendRow([
        TextCellValue("Order ID"),
        TextCellValue("Customer Name"),
        TextCellValue("Cashier"),
        TextCellValue("Created At"),
        TextCellValue("End Time"),
        TextCellValue("Payment"),
        TextCellValue("Status"),
        TextCellValue("Table"),
        TextCellValue("Total"),
        TextCellValue("Type"),
        TextCellValue("Item Name"),
        TextCellValue("Category"),
        TextCellValue("Qty"),
        TextCellValue("Price"),
        TextCellValue("Size"),
        TextCellValue("Disc (%)"),
        TextCellValue("Disc Nominal"),
        TextCellValue("Note"),
      ]);

      // DATA UNTUK CHART
      Map<String, int> dailySales = {}; // Line chart data
      Map<String, int> categoryCount = {}; // Pie chart data
      Map<String, int> menuCount = {}; // Bar chart data
      // COLLECT FILTERED DATA DULU
      List<Map<String, dynamic>> filteredData = [];

      for (var doc in allDocs) {
        final dataMap = doc.data();

        // PARSE CREATED_AT
        DateTime createdAt;
        final createdAtRaw = dataMap['created_at'];
        if (createdAtRaw is Timestamp) {
          createdAt = createdAtRaw.toDate();
        } else if (createdAtRaw is String) {
          createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
        } else {
          createdAt = DateTime.now();
        }

        // PARSE END_TIME
        DateTime? endTime;
        final endRaw = dataMap['endTime'];
        if (endRaw is Timestamp) {
          endTime = endRaw.toDate();
        } else if (endRaw is String) {
          endTime = DateTime.tryParse(endRaw);
        }

        // FILTER DATE
        if (createdAt.isBefore(startDate) || createdAt.isAfter(endDate)) continue;

        // FILTER STATUS
        final status = (dataMap['status'] ?? '').toString().toLowerCase();
        if (selectedStatus.toLowerCase() != "all" &&
            status != selectedStatus.toLowerCase()) {
          continue;
        }

        // Tambahkan ke list dengan createdAt untuk sorting nanti
        filteredData.add({
          'dataMap': dataMap,
          'createdAt': createdAt,
          'endTime': endTime,
        });
      }

      // ✅ SORTING: DARI TERLAMA KE TERBARU (ASCENDING)
      filteredData.sort((a, b) {
        DateTime dateA = a['createdAt'] as DateTime;
        DateTime dateB = b['createdAt'] as DateTime;
        return dateA.compareTo(dateB); // Ascending = terlama dulu
      });

      // SEKARANG PROCESS DATA YANG SUDAH TERSORTIR
      for (var filtered in filteredData) {
        final dataMap = filtered['dataMap'] as Map<String, dynamic>;
        final createdAt = filtered['createdAt'] as DateTime;
        final endTime = filtered['endTime'] as DateTime?;

        // COUNT DAILY SALES (untuk line chart)
        String dateKey = DateFormat('dd/MM/yyyy').format(createdAt);
        dailySales[dateKey] = (dailySales[dateKey] ?? 0) + 1;

        final items = (dataMap['items'] as List?) ?? [];

        final int startRow = sheet.maxRows + 1;

        for (var item in items) {
          final itemMap = item as Map<String, dynamic>? ?? {};

          // COUNT CATEGORY (untuk pie chart)
          final categories = itemMap['category'] as List<dynamic>?;
          final cat = categories != null && categories.isNotEmpty
              ? categories.first.toString()
              : "Uncategorized";
          int qty = itemMap['qty'] as int? ?? 0;
          categoryCount[cat] = (categoryCount[cat] ?? 0) + qty;

          // COUNT MENU (untuk bar chart)
          final menuName = itemMap['name']?.toString() ?? 'Unknown';
          menuCount[menuName] = (menuCount[menuName] ?? 0) + qty;

          // APPEND ROW DATA
          sheet.appendRow([
            TextCellValue(dataMap['order_id']?.toString() ?? '-'),
            TextCellValue(dataMap['customer_name']?.toString() ?? '-'),
            TextCellValue(dataMap['cashier']?.toString() ?? '-'),
            TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(createdAt)),
            TextCellValue(endTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(endTime) : '-'),
            TextCellValue(dataMap['payment']?.toString() ?? '-'),
            TextCellValue(dataMap['status']?.toString() ?? '-'),
            TextCellValue(dataMap['table']?.toString() ?? '-'),
            IntCellValue(0),
            TextCellValue(dataMap['type']?.toString() ?? '-'),
            TextCellValue(itemMap['name']?.toString() ?? '-'),
            TextCellValue(cat),
            IntCellValue(qty),
            IntCellValue(itemMap['price'] as int? ?? 0),
            TextCellValue(itemMap['size']?.toString() ?? '-'),
            TextCellValue(itemMap['disc']?.toString() ?? '0'),
            TextCellValue(itemMap['discNominal']?.toString() ?? '0'),
            TextCellValue(itemMap['noted']?.toString() ?? '-'),
          ]);
        }
        final int endRow = sheet.maxRows;

        if (endRow > startRow) {
          // Kolom TOTAL ada di kolom ke-9 → berarti kolom I
          sheet.merge(
            CellIndex.indexByString('I$startRow'),
            CellIndex.indexByString('I$endRow'),
          );
        }

        sheet
        .cell(CellIndex.indexByString('I$startRow'))
        .value = IntCellValue(dataMap['total'] as int? ?? 0);

      }

      // ========== SHEET 2: LINE CHART DATA (Daily Sales) ==========
      final lineSheet = excel['Chart - Daily Sales'];
      lineSheet.appendRow([
        TextCellValue("Date"),
        TextCellValue("Total Orders"),
      ]);

      // Sort by date
      final sortedDailySales = dailySales.entries.toList()
        ..sort((a, b) {
          try {
            final dateA = DateFormat('dd/MM/yyyy').parse(a.key);
            final dateB = DateFormat('dd/MM/yyyy').parse(b.key);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });

      for (var entry in sortedDailySales) {
        lineSheet.appendRow([
          TextCellValue(entry.key),
          IntCellValue(entry.value),
        ]);
      }

      // TUTORIAL LINE CHART
      final lineRowCount = sortedDailySales.length + 1;
      lineSheet.appendRow([TextCellValue("")]);
      lineSheet.appendRow([TextCellValue("")]);
      lineSheet.appendRow([TextCellValue("📊 CARA MEMBUAT LINE CHART (Grafik Garis Penjualan Harian):")]);
      lineSheet.appendRow([TextCellValue("")]);
      lineSheet.appendRow([TextCellValue("Langkah 1: Select/Blok data dari cell A1 sampai B$lineRowCount")]);
      lineSheet.appendRow([TextCellValue("Langkah 2: Klik tab 'Insert' di menu atas Excel")]);
      lineSheet.appendRow([TextCellValue("Langkah 3: Pilih 'Line Chart' atau 'Line with Markers'")]);
      lineSheet.appendRow([TextCellValue("Langkah 4: Chart akan otomatis muncul!")]);
      lineSheet.appendRow([TextCellValue("")]);
      lineSheet.appendRow([TextCellValue("💡 Tips: Klik chart → Chart Design → Add Chart Element untuk menambah judul")]);

      // ========== SHEET 3: PIE CHART DATA (Category Sales) ==========
      final pieSheet = excel['Chart - Category'];
      pieSheet.appendRow([
        TextCellValue("Category"),
        TextCellValue("Total Sold"),
      ]);

      for (var entry in categoryCount.entries) {
        pieSheet.appendRow([
          TextCellValue(entry.key),
          IntCellValue(entry.value),
        ]);
      }

      // TUTORIAL PIE CHART
      final pieRowCount = categoryCount.length + 1;
      pieSheet.appendRow([TextCellValue("")]);
      pieSheet.appendRow([TextCellValue("")]);
      pieSheet.appendRow([TextCellValue("🥧 CARA MEMBUAT PIE CHART (Grafik Lingkaran Kategori):")]);
      pieSheet.appendRow([TextCellValue("")]);
      pieSheet.appendRow([TextCellValue("Langkah 1: Select/Blok data dari cell A1 sampai B$pieRowCount")]);
      pieSheet.appendRow([TextCellValue("Langkah 2: Klik tab 'Insert' di menu atas Excel")]);
      pieSheet.appendRow([TextCellValue("Langkah 3: Pilih 'Pie Chart' → pilih jenis yang disukai (2D atau 3D)")]);
      pieSheet.appendRow([TextCellValue("Langkah 4: Chart akan otomatis muncul dengan persentase!")]);
      pieSheet.appendRow([TextCellValue("")]);
      pieSheet.appendRow([TextCellValue("💡 Tips: Klik chart → klik kanan → Add Data Labels untuk tampilkan angka")]);

      // ========== SHEET 4: BAR CHART DATA (Top 5 Menu) ==========
      final barSheet = excel['Chart - Top 5 Menu'];
      barSheet.appendRow([
        TextCellValue("Menu Name"),
        TextCellValue("Total Sold"),
      ]);

      // Sort and take top 5
      final sortedMenu = menuCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final top5 = sortedMenu.take(5);

      for (var entry in top5) {
        barSheet.appendRow([
          TextCellValue(entry.key),
          IntCellValue(entry.value),
        ]);
      }

      // TUTORIAL BAR CHART
      final top5Count = top5.length + 1;
      barSheet.appendRow([TextCellValue("")]);
      barSheet.appendRow([TextCellValue("")]);
      barSheet.appendRow([TextCellValue("📊 CARA MEMBUAT BAR CHART (Grafik Batang Top 5 Menu):")]);
      barSheet.appendRow([TextCellValue("")]);
      barSheet.appendRow([TextCellValue("Langkah 1: Select/Blok data dari cell A1 sampai B$top5Count")]);
      barSheet.appendRow([TextCellValue("Langkah 2: Klik tab 'Insert' di menu atas Excel")]);
      barSheet.appendRow([TextCellValue("Langkah 3: Pilih 'Bar Chart' (horizontal) atau 'Column Chart' (vertikal)")]);
      barSheet.appendRow([TextCellValue("Langkah 4: Chart akan otomatis muncul!")]);
      barSheet.appendRow([TextCellValue("")]);
      barSheet.appendRow([TextCellValue("💡 Tips: Pilih 'Column Chart' agar lebih mudah dibaca")]);

      // ========== SHEET 5: PANDUAN LENGKAP ==========
      final guideSheet = excel['📖 Panduan Lengkap'];
      
      guideSheet.appendRow([TextCellValue("═══════════════════════════════════════════════════════════")]);
      guideSheet.appendRow([TextCellValue("📊 PANDUAN LENGKAP MEMBUAT CHART DI EXCEL")]);
      guideSheet.appendRow([TextCellValue("═══════════════════════════════════════════════════════════")]);
      guideSheet.appendRow([TextCellValue("")]);
      
      guideSheet.appendRow([TextCellValue("📌 ISI FILE EXCEL INI:")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("✅ Sheet 1: Daily Report - Data transaksi lengkap")]);
      guideSheet.appendRow([TextCellValue("✅ Sheet 2: Chart - Daily Sales - Data untuk grafik penjualan harian")]);
      guideSheet.appendRow([TextCellValue("✅ Sheet 3: Chart - Category - Data untuk grafik kategori")]);
      guideSheet.appendRow([TextCellValue("✅ Sheet 4: Chart - Top 5 Menu - Data untuk grafik menu terlaris")]);
      guideSheet.appendRow([TextCellValue("✅ Sheet 5: Panduan Lengkap (sheet ini)")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("")]);

      guideSheet.appendRow([TextCellValue("🎯 CARA CEPAT MEMBUAT CHART:")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("1️⃣ Buka sheet yang ingin dibuat chartnya")]);
      guideSheet.appendRow([TextCellValue("2️⃣ Blok/Select semua data (dari kolom header sampai data terakhir)")]);
      guideSheet.appendRow([TextCellValue("3️⃣ Tekan tombol F11 untuk instant chart! (atau Insert → Chart)")]);
      guideSheet.appendRow([TextCellValue("4️⃣ Selesai! Chart otomatis terbuat")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("")]);

      guideSheet.appendRow([TextCellValue("🔥 SHORTCUT KEYBOARD BERGUNA:")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("• F11 = Buat chart instant dari data yang diblok")]);
      guideSheet.appendRow([TextCellValue("• Ctrl + A = Select semua data di sheet")]);
      guideSheet.appendRow([TextCellValue("• Alt + F1 = Buat embedded chart di sheet yang sama")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("")]);

      guideSheet.appendRow([TextCellValue("💡 TIPS PRO:")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("✨ Gunakan 'Recommended Charts' kalau bingung pilih jenis chart")]);
      guideSheet.appendRow([TextCellValue("✨ Klik kanan chart → Change Chart Type untuk ganti jenis")]);
      guideSheet.appendRow([TextCellValue("✨ Tambah Data Labels agar angka terlihat di chart")]);
      guideSheet.appendRow([TextCellValue("✨ Gunakan Chart Styles untuk tampilan yang lebih menarik")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("")]);

      guideSheet.appendRow([TextCellValue("📱 UNTUK EXCEL DI SMARTPHONE:")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("1. Buka file Excel di aplikasi Microsoft Excel")]);
      guideSheet.appendRow([TextCellValue("2. Pilih sheet chart yang ingin dibuat")]);
      guideSheet.appendRow([TextCellValue("3. Tap dan drag untuk select data")]);
      guideSheet.appendRow([TextCellValue("4. Tap icon '+' → Insert → Charts")]);
      guideSheet.appendRow([TextCellValue("5. Pilih jenis chart yang diinginkan")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("")]);

      guideSheet.appendRow([TextCellValue("❓ JENIS-JENIS CHART:")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("📈 Line Chart = Untuk melihat tren/perubahan dari waktu ke waktu")]);
      guideSheet.appendRow([TextCellValue("🥧 Pie Chart = Untuk melihat proporsi/perbandingan bagian dari keseluruhan")]);
      guideSheet.appendRow([TextCellValue("📊 Bar/Column Chart = Untuk membandingkan nilai antar kategori")]);
      guideSheet.appendRow([TextCellValue("")]);
      guideSheet.appendRow([TextCellValue("")]);

      guideSheet.appendRow([TextCellValue("═══════════════════════════════════════════════════════════")]);
      guideSheet.appendRow([TextCellValue("✅ Selamat mencoba! Data sudah siap untuk divisualisasikan!")]);
      guideSheet.appendRow([TextCellValue("═══════════════════════════════════════════════════════════")]);

      // SAVE EXCEL
      final fileBytes = excel.save();
      if (fileBytes == null) return;

      final fileName = "Daily_Report_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}";

      if (kIsWeb) {
        downloadExcelWeb(fileBytes, "$fileName.xlsx");
      } else {
        await downloadExcelMobile(fileBytes, fileName);
      }
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
            // Membuat ukuran dialog lebih kecil
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
            currentPage = 1;
          });
        }
      }

  @override
  Widget build(BuildContext context) {
    return SidebarWrapper(
      storeId: widget.storeId,
      role: "Owner",
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stores')
                .doc(widget.storeId)
                .collection('orders')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(
                    child: Text("Error loading data"));
              }

              final docs = snapshot.data?.docs ?? [];

              // Filter date
              final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // FILTER BY DATE
              if (_startDate != null && _endDate != null) {
                final createdAtRaw = data['created_at'];
                DateTime dateTime;
                if (createdAtRaw is Timestamp) {
                  dateTime = createdAtRaw.toDate();
                } else if (createdAtRaw is String) {
                  dateTime = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
                } else {
                  dateTime = DateTime.now();
                }
                if (dateTime.isBefore(_startDate!) || dateTime.isAfter(_endDate!)) {
                  return false;
                }
              }

              final stat = (data['status'] ?? '').toString().toLowerCase();
              if (stat == "pending") return false;

              // FILTER BY STATUS
              if (selectedStatus != "All") {
                final status = (data['status'] ?? '').toString().toLowerCase();
                if (selectedStatus.toLowerCase() != status) {
                  return false;
                }
              }

              return true;
            }).toList();

              filteredDocs.sort((a, b) {
              DateTime dateA;
              DateTime dateB;

              final aCreated = (a.data() as Map<String, dynamic>)['created_at'];
              final bCreated = (b.data() as Map<String, dynamic>)['created_at'];

              if (aCreated is Timestamp) {
                dateA = aCreated.toDate();
              } else if (aCreated is String) {
                dateA = DateTime.tryParse(aCreated) ?? DateTime.now();
              } else {
                dateA = DateTime.now();
              }

              if (bCreated is Timestamp) {
                dateB = bCreated.toDate();
              } else if (bCreated is String) {
                dateB = DateTime.tryParse(bCreated) ?? DateTime.now();
              } else {
                dateB = DateTime.now();
              }

              // Descending → terbaru dulu
              return dateB.compareTo(dateA);
            });

              // ==========================
              // COUNT ORDER BY CATEGORY
              // ==========================
              // CATEGORY COUNT
              Map<String, int> categoryCount = {};
              for (var doc in filteredDocs) {  // <--- pakai filteredDocs
                final data = doc.data() as Map<String, dynamic>;
                final items = (data['items'] as List?) ?? [];
                for (var item in items) {
                  final itemMap = item as Map<String, dynamic>;
                  final categories = itemMap['category'] as List<dynamic>?;
                  final cat = categories != null && categories.isNotEmpty
                      ? categories.first.toString()
                      : "Uncategorized";

                  categoryCount[cat] = (categoryCount[cat] ?? 0) + ((itemMap['qty'] ?? 1) as int);
                }
              }

              // ORDER TYPE COUNT
              int dineIn = 0, takeAway = 0, delivery = 0;
              Map<String, int> menuCount = {};

              for (var doc in filteredDocs) {  // <--- pakai filteredDocs
                final data = doc.data() as Map<String, dynamic>;
                final type = (data['type'] ?? '').toString().split('.').last.toLowerCase();

                if (type == 'dinein') dineIn++;
                if (type == 'takeaway') takeAway++;
                if (type == 'delivery') delivery++;

                final items = (data['items'] as List?) ?? [];
                for (var item in items) {
                  final name = (item['name'] ?? '').toString();
                  if (name.isNotEmpty) {
                    menuCount[name] = (menuCount[name] ?? 0) + 1;
                  }
                }
              }

              final total = dineIn + takeAway + delivery;
              final mostBought = menuCount.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final pieData = total > 0
                  ? [
                      PieChartSectionData(
                          color: Colors.green.shade700,
                          value: dineIn.toDouble(),
                          title: ''),
                      PieChartSectionData(
                          color: Colors.purple.shade800,
                          value: delivery.toDouble(),
                          title: ''),
                      PieChartSectionData(
                          color: Colors.blue.shade800,
                          value: takeAway.toDouble(),
                          title: ''),
                    ]
                  : [
                      PieChartSectionData(
                          color: Colors.grey.shade300,
                          value: 1,
                          title: '')
                    ];

              return Padding(
                padding: const EdgeInsets.all(24),
                child: FutureBuilder<List<String>>(
                  future: getCategories(),
                  builder: (context, categorySnap) {
                    
                    final allCategoryKeys = categoryCount.keys.toList();

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: const [
                                Icon(Icons.account_circle,
                                    size: 32, color: Colors.brown),
                                SizedBox(width: 8),
                                Text(
                                  "Hi, Owner",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ============================================
                          // NEW ANALYTICS BOXES — BASED ON CATEGORY
                          // ============================================
                          const Text(
                            "Analytics by Category",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: allCategoryKeys.map((cat) {
                              return SizedBox(
                                width: 180,
                                child: InkWell(
                                  onTap: () => _showCategoryDetail(cat, filteredDocs),
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildAnimatedBox(
                                    cat,
                                    categoryCount[cat] ?? 0,
                                    Colors.amber.shade700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 32),

                          // ============================================
                          // ANALYTICS BY ORDER TYPE
                          // ============================================
                          const Text(
                            "Analytics Overview",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Flexible(
                                  child: _buildAnimatedBox(
                                      "Total Orders",
                                      total,
                                      Colors.amber.shade700)),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: _buildAnimatedBox(
                                      "Delivery",
                                      delivery,
                                      Colors.purple.shade700)),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: _buildAnimatedBox(
                                      "Take Away",
                                      takeAway,
                                      Colors.blue.shade700)),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: _buildAnimatedBox(
                                      "Dine In",
                                      dineIn,
                                      Colors.green.shade700)),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // FILTER ROW
                          Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                              if (_startDate == null || _endDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Silakan pilih tanggal dulu.")),
                                );
                                return;
                              }

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );

                              await downloadDailyReportExcel(
                                widget.storeId,
                                _startDate!,
                                _endDate!,
                                selectedStatus,
                              );

                              Navigator.of(context).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Excel berhasil diunduh!")),
                              );
                            },
                            icon: const Icon(Icons.download),
                            label: const Text("Download Excel"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // BUTTON FILTER DATE
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

                            // DROPDOWN FILTER STATUS
                            DropdownButton<String>(
                              value: selectedStatus,
                              items: statusOptions
                                  .map((status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedStatus = value;
                                    currentPage = 1;
                                  });
                                }
                              },
                            ),

                            // Tampilkan tanggal range jika ada
                            if (_startDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(left: 12),
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade100.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${DateFormat('yyyy-MM-dd').format(_startDate!)} → ${DateFormat('yyyy-MM-dd').format(_endDate!)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.brown,
                                  ),
                                ),
                              ),
                          ],
                        ),

                          const SizedBox(height: 16),

                          // TABLE + PIECHART
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width:
                                    MediaQuery.of(context)
                                            .size
                                            .width *
                                        0.50,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 420,
                                      child:
                                          SingleChildScrollView(
                                        scrollDirection:
                                            Axis.horizontal,
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(
                                                label: Text(
                                                    "Orders Date")),
                                            DataColumn(
                                                label: Text(
                                                    "Customers Name")),
                                            DataColumn(
                                                label: Text(
                                                    "Order Type")),
                                            DataColumn(
                                                label: Text(
                                                    "Order Id")),
                                            DataColumn(
                                                label: Text(
                                                    "Total Price")),
                                            DataColumn(
                                                label: Text(
                                                    "Status")),
                                            DataColumn(
                                                label: Text(
                                                    "Payment")),
                                            DataColumn(
                                                label: Text(
                                                    "Cashier")),
                                          ],
                                          rows: filteredDocs.isEmpty
                                        ? [
                                            const DataRow(
                                              cells: [
                                                DataCell(Text("Maaf data tidak ditemukan", textAlign: TextAlign.center), placeholder: true),
                                                DataCell(Text(""), placeholder: true),
                                                DataCell(Text(""), placeholder: true),
                                                DataCell(Text(""), placeholder: true),
                                                DataCell(Text(""), placeholder: true),
                                                DataCell(Text(""), placeholder: true),
                                              ],
                                            )
                                          ]
                                        : getPagedData(filteredDocs).map((doc) {
                                            final d = doc.data() as Map<String, dynamic>;
                                            final orderType = (d['type'] ?? '').toString().split('.').last;

                                            String formattedDate = '-';
                                            final createdAt = d['created_at'];
                                            if (createdAt != null) {
                                              DateTime dateTime;
                                              if (createdAt is Timestamp) {
                                                dateTime = createdAt.toDate();
                                              } else if (createdAt is String) {
                                                dateTime = DateTime.tryParse(createdAt) ?? DateTime.now();
                                              } else {
                                                dateTime = DateTime.now();
                                              }
                                              formattedDate = DateFormat('d/M/yyyy, HH.mm').format(dateTime);
                                            }

                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(formattedDate),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(d['customer_name']?.toString() ?? '-'),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(orderType),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(d['order_id']?.toString() ?? '-'),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text("Rp. ${d['total']?.toString() ?? '0'}"),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(d['status']?.toString() ?? '-'),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(d['payment']?.toString() ?? '-'),
                                                  ),
                                                ),
                                                DataCell(
                                                  InkWell(
                                                    onTap: () => _showOrderDetail(d),
                                                    child: Text(d['cashier']?.toString() ?? '-'),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 12),

                                    // PAGINATION
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                                        ),
                                        
                                        // PAGINATION DYNAMIC
                                        ..._buildPaginationNumbers(filteredDocs.length, rowsPerPage),

                                        IconButton(
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed: currentPage < (filteredDocs.length / rowsPerPage).ceil()
                                              ? () => setState(() => currentPage++)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 24),

                              // PIE + MOST BUY
                              SizedBox(
                                width:
                                    MediaQuery.of(context)
                                            .size
                                            .width *
                                        0.35,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 200,
                                      child:
                                          TweenAnimationBuilder<
                                              double>(
                                        tween: Tween(
                                            begin: 0, end: 1),
                                        duration:
                                            const Duration(
                                                seconds: 1),
                                        builder: (context,
                                            value,
                                            child) {
                                          return PieChart(
                                            PieChartData(
                                              sections: pieData
                                                  .map((p) =>
                                                      PieChartSectionData(
                                                        color:
                                                            p.color,
                                                        value: p.value *
                                                            value,
                                                        title:
                                                            '',
                                                      ))
                                                  .toList(),
                                              centerSpaceRadius:
                                                  40,
                                              borderData:
                                                  FlBorderData(
                                                      show:
                                                          false),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 16),

                                    Container(
                                      width:
                                          double.infinity,
                                      padding:
                                          const EdgeInsets
                                                  .all(
                                              16),
                                      decoration:
                                          BoxDecoration(
                                        color: const Color(
                                            0xFFFFF3D4),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          const Text(
                                            "Most Buy Menu",
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(
                                              height: 8),

                                          for (var menu
                                              in mostBought
                                                  .take(5))
                                            Padding(
                                              padding:
                                                  const EdgeInsets
                                                          .symmetric(
                                                      vertical:
                                                          4),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(menu
                                                      .key),
                                                  Text(menu
                                                      .value
                                                      .toString()),
                                                ],
                                              ),
                                            ),

                                          if (mostBought
                                              .isEmpty)
                                            const Text(
                                              "No data available",
                                              style: TextStyle(
                                                  color: Colors
                                                      .grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPaginationNumbers(int totalItems, int rowsPerPage) {
    int totalPages = (totalItems / rowsPerPage).ceil();
    int maxButtons = 3; // Maksimal tombol halaman yang muncul
    List<Widget> buttons = [];

    int startPage = currentPage;
    int endPage = currentPage + maxButtons - 1;

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
        child: InkWell(
          onTap: () => setState(() => currentPage = i),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: currentPage == i ? Colors.brown : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "$i",
              style: TextStyle(
                color: currentPage == i ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
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

  Widget _buildAnimatedBox(
      String title, int count, Color color) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: count),
          duration: const Duration(seconds: 1),
          builder: (context, value, child) {
            return Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  value.toString().padLeft(3, '0'),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500)),
              ],
            );
          },
        ),
      ),
    );
  }
}
