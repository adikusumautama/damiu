// lib/screens/admin/admin_prediction_view_screen.dart
// Widget ini sekarang khusus untuk menampilkan grafik dan detail prediksi.
import 'package:damiu/services/firestore_service.dart'; // Tambahkan impor ini
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/prediction_result_model.dart'; // Import model prediksi baru
import 'package:damiu/services/prediction_service.dart';
import 'package:damiu/screens/admin/prediction_chart_widget.dart'; // Impor widget grafik
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:flutter/material.dart'; // Pastikan Flutter Material diimpor

class AdminPredictionViewScreen extends StatefulWidget {
  const AdminPredictionViewScreen({super.key});

  @override
  State<AdminPredictionViewScreen> createState() => _AdminPredictionViewScreenState();
}

class _AdminPredictionViewScreenState extends State<AdminPredictionViewScreen> {
  final FirestoreService _firestoreService = FirestoreService(); // Pastikan ini ada dan tidak terkomentari
  final PredictionService _predictionService = PredictionService();
  Future<ApiPredictionResult>? _predictionFuture; // Untuk menampung future prediksi
  List<DailySale> _allSalesData = []; // Untuk menyimpan data historis
  final int _daysToPredictCount = 7;

  @override
  void initState() {
    super.initState();
    _loadDataAndPredictions();
  }

  void _loadDataAndPredictions() {
    // API Flask yang diubah sekarang mengambil data historis sendiri (dari Firestore atau CSV).
    // Kita hanya perlu memanggil API prediksi.
    // Data historis untuk grafik akan diambil dari API response jika tersedia,
    // atau mungkin perlu endpoint terpisah jika API prediksi hanya mengembalikan 1 hari.
    // Asumsi: API prediksi yang baru HANYA mengembalikan prediksi untuk besok.
    // Untuk menampilkan grafik historis + 1 hari prediksi, kita perlu endpoint terpisah
    // untuk data historis, atau API prediksi mengembalikan data historis juga.
    // Berdasarkan diff Python sebelumnya, API prediksi HANYA mengembalikan prediksi 1 hari.
    // Jadi, kita perlu endpoint terpisah untuk data historis untuk grafik.
    // Mari kita asumsikan ada endpoint baru `/history` atau kita tetap ambil dari Firestore untuk grafik.
    // Kita tetap ambil dari Firestore untuk grafik, dan API prediksi hanya untuk nilai prediksi besok.

    // Ambil data historis untuk grafik
    _firestoreService.getDailySalesOnce().then((salesData) { // <-- FirestoreService masih dibutuhkan untuk grafik
      if (mounted) {
        setState(() {
          _allSalesData = salesData;
          _allSalesData.sort((a, b) => a.date.compareTo(b.date));

          // Panggil API prediksi untuk mendapatkan prediksi besok
          // Parameter daysToPredict tidak lagi relevan untuk API Flask yang diubah
          _predictionFuture = _predictionService.getPredictionsFromApi(
            // daysToPredict: _daysToPredictCount, // Parameter ini diabaikan oleh API Flask
            // dataSource: 'firestore', // Default ke firestore di API Flask jika tidak dikirim
          );
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          // Tangani error saat memuat data historis
          _predictionFuture = Future.value(ApiPredictionResult( // Gunakan constructor yang benar
            // predictedQuantities: [], // field ini tidak ada lagi di ApiPredictionResult
            success: false,
            errorMessage: 'Gagal memuat data historis: $error',
          ));
        });
      }
    });
  }

  Widget _buildInsufficientDataUI(String errorMessage) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Pusatkan konten utama secara horizontal
          mainAxisAlignment: MainAxisAlignment.center, // Pusatkan konten jika sedikit
          children: [
            // Judul Halaman
            Text(
              'Prediksi Permintaan Galon',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24), // Jarak setelah judul

            // Pesan Error/Informasi Data Tidak Cukup
            Text(
              errorMessage, // Gunakan pesan error dari ApiPredictionResult
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]), // Gaya teks pesan, sedikit diredam
              textAlign: TextAlign.center,
            ),
            if (_allSalesData.isNotEmpty) ...[ // Tampilkan data historis jika ada
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DataTable(
                     columns: const <DataColumn>[
                       DataColumn(label: Text('Tanggal')),
                       DataColumn(label: Text('Galon Terjual')),
                     ],
                     rows: _allSalesData.map((sale) => DataRow(cells: [
                       DataCell(Text(DateFormat('dd MMM yyyy', 'id_ID').format(sale.date))),
                       DataCell(Text(sale.quantity.toString())),
                     ])).toList(),
                  ),
                ),
              ),
            ],
            // Hapus tanda kurung penutup yang berlebihan di sini
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FutureBuilder akan menangani state loading awal dan error
    // Tidak perlu pengecekan _allSalesData.isEmpty && _predictionFuture == null di sini
    // atau _allSalesData.length < 2 && _predictionFuture != null secara terpisah

    return FutureBuilder<ApiPredictionResult>(
      future: _predictionFuture, // _predictionFuture diinisialisasi di initState/_loadDataAndPredictions
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Menampilkan loading indicator saat _predictionFuture sedang diproses
          return const Center(child: CircularProgressIndicator(key: ValueKey("prediction_load")));
        }
        if (snapshot.hasError) {
          // Menangani error dari Future itu sendiri (misalnya, network error sebelum API merespons)
          return Center(child: Text('Error memuat data prediksi: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          // Seharusnya tidak terjadi jika Future selalu mengembalikan ApiPredictionResult
          return const Center(child: Text('Tidak ada data hasil prediksi.'));
        }

        final ApiPredictionResult predictionResult = snapshot.data!;

        if (!predictionResult.success) {
          // Jika API call tidak sukses (termasuk kasus data tidak cukup)
          if (predictionResult.errorMessage == 'Tidak cukup data historis untuk prediksi.' ||
              predictionResult.errorMessage == 'Tidak ada data historis untuk prediksi.' || (predictionResult.errorMessage?.contains('minimal 14 hari') ?? false) ) {
            return _buildInsufficientDataUI(predictionResult.errorMessage!);
          }
          // Untuk error lain dari API
          return Center(child: Text(predictionResult.errorMessage ?? 'Gagal mendapatkan prediksi.'));
        }

        // Jika sukses
        final List<DailySale> predictedSalesForTable = []; // List untuk tabel, hanya 1 hari
        final List<double> predictedQuantitiesForChart = []; // Ubah ke List<double>

        if (predictionResult.predictionForNextDay != null) {
          // Tambahkan prediksi besok ke list untuk tabel
          predictedSalesForTable.add(DailySale(
            date: predictionResult.predictionForNextDay!.date,
            dayOfWeek: predictionResult.predictionForNextDay!.date.weekday,
            deliveryCount: 0, // Default
            quantity: predictionResult.predictionForNextDay!.predictedQuantity,
            isSynced: false, // Hanya tampilan
          ));
          // Tambahkan prediksi besok ke list untuk grafik
          predictedQuantitiesForChart.add(predictionResult.predictionForNextDay!.predictedQuantity.toDouble()); // Konversi ke double
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center( // Pusatkan judul utama
                  child: Text(
                    'Prediksi Permintaan Galon',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                if (_allSalesData.isNotEmpty)
                  PredictionChartWidget(
                    historicalSales: _allSalesData, // Data historis untuk grafik
                    predictedQuantities: predictedQuantitiesForChart, // Gunakan list yang sudah disiapkan
                    daysToPredict: _daysToPredictCount,
                  ) // Tutup PredictionChartWidget
                else // Seharusnya kondisi ini tidak tercapai jika predictionResult.success true
                  const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text("Data historis tidak tersedia untuk grafik."),
                      )),
                const ChartLegend(), // Sesuaikan legenda jika model berubah
                const SizedBox(height: 24), // Jarak sebelum detail prediksi (sekarang hanya 1 hari)
                Text('Detail Prediksi ${_daysToPredictCount} Hari ke Depan:', // Judul detail prediksi
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (predictedSalesForTable.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Tidak ada data prediksi yang bisa ditampilkan.'),
                  )
                // Tampilkan tabel hanya untuk prediksi besok
                else
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) {
                          return Theme.of(context).primaryColor.withOpacity(0.1);
                        }),
                        headingTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold, color: Colors.black87),
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Tanggal Prediksi')), // Sesuaikan label
                          DataColumn(label: Text('Hari')),
                          DataColumn(label: Text('Prediksi (Galon)')),
                        ],
                        rows: predictedSalesForTable.map((sale) {
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text(DateFormat('dd MMM yyyy', 'id_ID').format(sale.date))),
                              DataCell(Text(DateFormat('EEEE', 'id_ID').format(sale.date))),
                              DataCell(Text(sale.quantity.toString())),
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
      }, // Tutup FutureBuilder
    );
  }
}
       