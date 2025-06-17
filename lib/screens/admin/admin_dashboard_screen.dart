// lib/screens/admin/admin_dashboard_screen.dart (Modifikasi BerandaAdminContent)

// ... (import lainnya)
import 'package:damiu/models/daily_sale_model.dart'; // Ini sepertinya tidak terpakai langsung di sini, tapi LinearRegressionModel iya
import 'package:damiu/models/linear_regression_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/prediction_service.dart';
import 'package:damiu/screens/admin/prediction_chart_widget.dart'; // Impor widget grafik
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:flutter/material.dart'; // Pastikan Flutter Material diimpor

class BerandaAdminContent extends StatefulWidget {
  const BerandaAdminContent({super.key});

  @override
  State<BerandaAdminContent> createState() => _BerandaAdminContentState();
}

class _BerandaAdminContentState extends State<BerandaAdminContent> {
  final FirestoreService _firestoreService = FirestoreService();
  final PredictionService _predictionService = PredictionService();
  // final DataService _dataService = DataService(); // Hapus DataService
  // List<DailySale> _historicalSalesFromCsv = []; // Hapus variabel ini
  // @override
  // void initState() {
  //   super.initState();
  //   _loadHistoricalCsvData(); // Hapus pemanggilan method ini
  // }
  // Future<void> _loadHistoricalCsvData() async { // Hapus method ini
  //   final List<DailySale> csvSales = await _dataService.loadSalesDataFromCsv('assets/damiu.csv');
  //   if (mounted) {
  //     setState(() {
  //       _historicalSalesFromCsv = csvSales;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailySale>>(
      stream: _firestoreService.getDailySalesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Tampilkan loading jika data CSV belum dimuat dan stream masih menunggu
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error memuat data: ${snapshot.error}'));
        }

        final List<DailySale> allSalesData = snapshot.data ?? [];
        allSalesData.sort((a, b) => a.date.compareTo(b.date));

        if (allSalesData.isEmpty) {
          return const Center(child: Text('Belum ada data penjualan untuk ditampilkan.'));
        }

        final List<Map<String, double>> regressionData = [];
        final DateTime overallStartDate = allSalesData.first.date;

        // Data untuk regresi: 'day' adalah indeks hari (mulai dari 1), 'quantity' adalah kuantitas
        for (var sale in allSalesData) {
          // Indeks hari untuk model regresi, dimulai dari 1
          final double dayIndex = sale.date.difference(overallStartDate).inDays.toDouble() + 1;
          regressionData.add({'day': dayIndex, 'quantity': sale.quantity.toDouble()});
        }

        final LinearRegressionModel regressionModel = _predictionService.calculateLinearRegression(regressionData);
        
        // Indeks hari terakhir dari data historis yang digunakan untuk regresi
        final double lastModelInputDayIndex = regressionData.isNotEmpty ? regressionData.last['day']! : 0;

        final int daysToPredictCount = 7;
        final List<DailySale> predictedSales = [];

        for (int i = 1; i <= daysToPredictCount; i++) {
          // Indeks hari untuk prediksi, relatif terhadap input model regresi
          final double predictDayIndex = lastModelInputDayIndex + i;
          final DateTime predictDate = allSalesData.last.date.add(Duration(days: i));
          final double predictedQuantity = regressionModel.predict(predictDayIndex);
          predictedSales.add(DailySale(
            date: predictDate,
            dayOfWeek: predictDate.weekday,
            deliveryCount: 0, // Tambahkan deliveryCount untuk prediksi (default 0)
            quantity: predictedQuantity.round(),
            isSynced: false,
          ));
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allSalesData.isNotEmpty) // Hanya tampilkan grafik jika ada data
                  PredictionChartWidget(
                    historicalSales: allSalesData,
                    // predictedSales: predictedSales, // Widget grafik akan menghitung prediksinya sendiri berdasarkan model
                    regressionModel: regressionModel,
                    daysToPredict: daysToPredictCount,
                  ),
                const Text('Grafik Prediksi Permintaan Galon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const ChartLegend(),
                const SizedBox(height: 30),
                const Text('Detail Prediksi 7 Hari ke Depan:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (predictedSales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Tidak ada data prediksi yang bisa ditampilkan.'),
                  )
                else // Tampilkan DataTable jika ada data prediksi
                  SizedBox(
                    width: double.infinity, // Agar DataTable mengambil lebar penuh
                    child: Card( // Bungkus DataTable dengan Card untuk estetika
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DataTable(
                        columnSpacing: 20, // Atur jarak antar kolom
                        headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) {
                          return Theme.of(context).primaryColor.withOpacity(0.1);
                        }),
                        headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black87),
                        columns: const <DataColumn>[
                          DataColumn(
                            label: Text('Tanggal'),
                          ),
                          DataColumn(
                            label: Text('Hari'),
                          ),
                          DataColumn(
                            label: Text('Prediksi (Galon)'), // Hapus 'numeric: true' dari sini
                          ),
                        ],
                        rows: predictedSales.map((sale) {
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text(DateFormat('dd MMM yyyy', 'id_ID').format(sale.date))),
                              DataCell(Text(DateFormat('EEEE', 'id_ID').format(sale.date))),
                              DataCell(Text(sale.quantity.toString()), placeholder: false, /*showEditIcon: false, onTap: null,*/ ), // Perataan numerik diatur oleh DataTable secara default jika data adalah angka
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
