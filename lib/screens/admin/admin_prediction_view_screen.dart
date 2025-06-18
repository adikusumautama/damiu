// lib/screens/admin/admin_prediction_view_screen.dart
// Widget ini sekarang khusus untuk menampilkan grafik dan detail prediksi.
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/services/firestore_service.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
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
    // Ambil data historis sekali saja, atau gunakan stream jika ingin update real-time
    // Untuk prediksi, biasanya data historis diambil sekali saat akan membuat prediksi
    _firestoreService.getDailySalesOnce().then((salesData) {
      if (mounted) {
        setState(() {
          _allSalesData = salesData;
          _allSalesData.sort((a, b) => a.date.compareTo(b.date));

          // API sekarang mengambil histori dari Firestore, jadi kita hanya perlu memastikan ada data
          // untuk ditampilkan di grafik. Validasi jumlah data untuk prediksi dilakukan di API.
          // Namun, kita tetap butuh _allSalesData untuk grafik.
          // Panggilan API bisa dilakukan meskipun _allSalesData kosong, API akan handle.
          // Untuk UI, kita mungkin tetap ingin ada minimal data lokal sebelum mencoba prediksi.
          if (_allSalesData.isNotEmpty) { // Atau kondisi lain jika diperlukan untuk UI
            _predictionFuture = _predictionService.getPredictionsFromApi(
              daysToPredict: _daysToPredictCount,
            );
          } else {
            // Jika data historis kurang dari 14, set _predictionFuture ke hasil error
            // Ini akan ditangani oleh FutureBuilder untuk menampilkan pesan yang sesuai
            _predictionFuture = Future.value(ApiPredictionResult(
              predictedQuantities: [],
              success: false,
              errorMessage: 'Tidak ada data historis lokal untuk ditampilkan di grafik.',
            ));
          }
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _predictionFuture = Future.value(ApiPredictionResult(
            predictedQuantities: [],
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

        // Jika sukses dan ada data prediksi
        final List<DailySale> predictedSalesForTable = [];
        if (_allSalesData.isNotEmpty && predictionResult.predictedQuantities.isNotEmpty) {
          DateTime lastHistoricalDate = _allSalesData.last.date;
          for (int i = 0; i < predictionResult.predictedQuantities.length; i++) {
            final DateTime predictDate = lastHistoricalDate.add(Duration(days: i + 1));
            predictedSalesForTable.add(DailySale(
              date: predictDate,
              dayOfWeek: predictDate.weekday,
              deliveryCount: 0, // Default
              quantity: predictionResult.predictedQuantities[i].round(),
              isSynced: false, // Ini hanya tampilan, tidak disimpan
            ));
          }
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
                    historicalSales: _allSalesData,
                    predictedQuantities: predictionResult.predictedQuantities, // Pastikan ini sudah benar
                    daysToPredict: _daysToPredictCount,
                  ) // Tutup PredictionChartWidget
                else // Seharusnya kondisi ini tidak tercapai jika predictionResult.success true
                  const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text("Data historis tidak tersedia untuk grafik."),
                      )),
                const ChartLegend(), // Sesuaikan legenda jika model berubah
                const SizedBox(height: 24), // Jarak sebelum detail prediksi
                Text('Detail Prediksi ${_daysToPredictCount} Hari ke Depan:', // Judul detail prediksi
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (predictedSalesForTable.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Tidak ada data prediksi yang bisa ditampilkan.'),
                  )
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
                          DataColumn(label: Text('Tanggal')),
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
      },
    );
  }
}
       