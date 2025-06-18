// lib/screens/admin/admin_dashboard_screen.dart (Modifikasi BerandaAdminContent)

// ... (import lainnya)
import 'package:damiu/models/daily_sale_model.dart';
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
  Future<ApiPredictionResult>? _predictionFuture;
  List<DailySale> _currentAllSalesData = []; // Untuk menyimpan data historis saat ini
  final int _daysToPredictCount = 7;
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

  void _fetchPredictions(List<DailySale> salesData) {
    if (mounted) {
      _currentAllSalesData = List.from(salesData); // Simpan salinan data
      _currentAllSalesData.sort((a, b) => a.date.compareTo(b.date));

      // API sekarang mengambil histori dari Firestore.
      // Panggil API jika ada data untuk ditampilkan di grafik.
      if (_currentAllSalesData.isNotEmpty) {
        setState(() {
          _predictionFuture = _predictionService.getPredictionsFromApi(
            daysToPredict: _daysToPredictCount,
          );
        });
      } else {
        setState(() {
          _predictionFuture = Future.value(ApiPredictionResult(
            predictedQuantities: [],
            success: false,
            errorMessage: 'Tidak ada data historis lokal untuk ditampilkan di grafik.',
          ));
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Panggilan awal bisa dilakukan di sini jika stream tidak langsung emit data,
    // atau biarkan StreamBuilder yang memicu _fetchPredictions saat data pertama datang.
  }
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

        // Panggil _fetchPredictions ketika data dari stream berubah (dan valid)
        // Ini akan memicu pemanggilan API dan memperbarui _predictionFuture
        // Kita perlu cara agar ini tidak dipanggil berulang kali jika data stream sama.
        // Salah satu cara adalah membandingkan dengan _currentAllSalesData.
        // Namun, untuk StreamBuilder, ini akan dipanggil setiap kali stream emit.
        // Lebih baik jika _fetchPredictions dipanggil sekali saat data valid pertama datang
        // atau jika ada perubahan signifikan.
        // Untuk saat ini, kita panggil jika _predictionFuture null atau data berubah.
        if (allSalesData.isNotEmpty && (_predictionFuture == null || _currentAllSalesData.length != allSalesData.length)) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             _fetchPredictions(allSalesData);
           });
        } else if (allSalesData.isEmpty && _predictionFuture == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               setState(() {
                 _predictionFuture = Future.value(ApiPredictionResult(
                   predictedQuantities: [],
                   success: false,
                   errorMessage: 'Belum ada data penjualan untuk prediksi.',
                 ));
               });
            });
        }

        if (allSalesData.isEmpty) {
          return const Center(child: Text('Belum ada data penjualan untuk ditampilkan.'));
        }

        return FutureBuilder<ApiPredictionResult>(
          future: _predictionFuture,
          builder: (context, predictionSnapshot) {
            if (predictionSnapshot.connectionState == ConnectionState.waiting && _predictionFuture != null) {
              return const Center(child: CircularProgressIndicator(key: ValueKey("dashboard_prediction_load")));
            }
            if (predictionSnapshot.hasError) {
              return Center(child: Text('Error memuat prediksi: ${predictionSnapshot.error}'));
            }

            List<double> predictedQuantities = [];
            String? predictionErrorMessage;

            if (predictionSnapshot.hasData) {
              final result = predictionSnapshot.data!;
              if (result.success) {
                predictedQuantities = result.predictedQuantities;
              } else {
                predictionErrorMessage = result.errorMessage;
              }
            } else if (_predictionFuture == null && allSalesData.isNotEmpty) {
                 // Kasus di mana _fetchPredictions belum dipanggil atau selesai
                 return const Center(child: Text("Memuat data prediksi..."));
            }


            final List<DailySale> predictedSalesForTable = [];
            if (allSalesData.isNotEmpty && predictedQuantities.isNotEmpty) {
              DateTime lastHistoricalDate = allSalesData.last.date;
              for (int i = 0; i < predictedQuantities.length; i++) {
                final DateTime predictDate = lastHistoricalDate.add(Duration(days: i + 1));
                predictedSalesForTable.add(DailySale(
                  date: predictDate,
                  dayOfWeek: predictDate.weekday,
                  deliveryCount: 0,
                  quantity: predictedQuantities[i].round(),
                  isSynced: false,
                ));
              }
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Center(child: Text('Grafik Prediksi Permintaan Galon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    if (allSalesData.isNotEmpty)
                      PredictionChartWidget(
                        historicalSales: allSalesData,
                        predictedQuantities: predictedQuantities, // Pastikan ini sudah benar
                        daysToPredict: _daysToPredictCount,
                      )
                    else
                      const Center(child: Text("Data historis tidak tersedia untuk grafik.")),
                    if (predictionErrorMessage != null && predictionErrorMessage.isNotEmpty && allSalesData.isNotEmpty)
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                         child: Center(child: Text(predictionErrorMessage, style: const TextStyle(color: Colors.red))),
                       ),
                    const ChartLegend(),
                    const SizedBox(height: 30),
                    const Text('Detail Prediksi 7 Hari ke Depan:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (predictedSalesForTable.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(predictionErrorMessage != null && predictionErrorMessage.contains("Tidak cukup data")
                            ? predictionErrorMessage
                            : 'Tidak ada data prediksi yang bisa ditampilkan.'),
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
                            headingTextStyle: const TextStyle(
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
      },
    );
  }
}
