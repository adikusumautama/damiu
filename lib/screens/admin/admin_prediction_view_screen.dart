// lib/screens/admin/admin_prediction_view_screen.dart
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/prediction_result_model.dart';
import 'package:damiu/services/prediction_service.dart';
import 'package:damiu/screens/admin/prediction_chart_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class AdminPredictionViewScreen extends StatefulWidget {
  const AdminPredictionViewScreen({super.key});
  @override
  State<AdminPredictionViewScreen> createState() => _AdminPredictionViewScreenState();
}

class _AdminPredictionViewScreenState extends State<AdminPredictionViewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PredictionService _predictionService = PredictionService();
  Future<ApiPredictionResult>? _predictionFuture;
  List<DailySale> _allSalesData = [];

  @override
  void initState() {
    super.initState();
    _loadDataAndPredictions();
  }

  void _loadDataAndPredictions() {
    _firestoreService.getDailySalesOnce().then((salesData) {
      if (!mounted) return;
      setState(() {
        _allSalesData = salesData;
        _allSalesData.sort((a, b) => a.date.compareTo(b.date));
        _predictionFuture = _predictionService.getPredictionsFromApi();
      });
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _predictionFuture = Future.value(ApiPredictionResult(success: false, errorMessage: 'Gagal memuat data historis: $error'));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiPredictionResult>(
      future: _predictionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: Text('Tidak ada data hasil prediksi.'));

        final result = snapshot.data!;
        if (!result.success) return Center(child: Text(result.errorMessage ?? 'Gagal mendapatkan prediksi.'));
        
        final predictedSales = [if (result.predictionForNextDay != null) DailySale(date: result.predictionForNextDay!.date, deliveryCount: 0, quantity: result.predictionForNextDay!.predictedQuantity)];
        final predictedQuantities = [if (result.predictionForNextDay != null) result.predictionForNextDay!.predictedQuantity.toDouble()];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Prediksi Permintaan Galon', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (_allSalesData.isNotEmpty)
                PredictionChartWidget(historicalSales: _allSalesData, predictedQuantities: predictedQuantities, daysToPredict: 7)
              else
                const Center(child: Text("Data historis tidak tersedia untuk grafik.")),
              const ChartLegend(),
              const SizedBox(height: 24),
              Text('Detail Prediksi', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  child: DataTable(
                    columns: const [DataColumn(label: Text('Tanggal')), DataColumn(label: Text('Hari')), DataColumn(label: Text('Prediksi (Galon)'))],
                    rows: predictedSales.map((sale) => DataRow(cells: [
                      DataCell(Text(DateFormat('dd MMM yy', 'id_ID').format(sale.date))),
                      DataCell(Text(DateFormat('EEEE', 'id_ID').format(sale.date))),
                      DataCell(Text(sale.quantity.toString())),
                    ])).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}