// lib/services/prediction_service.dart
import 'dart:convert'; // Untuk jsonDecode
import 'package:http/http.dart' as http;

// Anda mungkin ingin membuat model untuk menampung hasil prediksi dari API
// jika responsnya lebih kompleks. Untuk contoh ini, kita asumsikan API
// mengembalikan list angka (prediksi untuk beberapa hari ke depan).
class ApiPredictionResult {
  final List<double> predictedQuantities;
  final bool success;
  final String? errorMessage;

  ApiPredictionResult({
    required this.predictedQuantities,
    this.success = true,
    this.errorMessage,
  });
}

class PredictionService {
  // URL API Backend Anda (ganti dengan URL sebenarnya)
  // final String _apiBaseUrl = 'http://127.0.0.1:5000/predict'; // SALAH jika dari emulator/HP
  // Gunakan IP ini jika menjalankan Flutter di Emulator Android dan Flask di PC yang sama
  // final String _apiBaseUrl = 'http://10.0.2.2:5000/predict';
  // Gunakan IP lokal PC Anda jika menjalankan Flutter di HP pada WiFi yang sama (ganti dengan IP Anda)
  final String _apiBaseUrl = 'http://192.168.236.78:5000/predict'; // GANTI DENGAN IP LOKAL PC ANDA

  // Fungsi untuk mendapatkan prediksi dari API
  // `lastHistoricalDate` adalah tanggal terakhir dari data historis yang diketahui (format YYYY-MM-DD)
  // `daysToPredict` adalah berapa hari ke depan yang ingin diprediksi
  Future<ApiPredictionResult> getPredictionsFromApi({
    required String lastHistoricalDate, 
    required int daysToPredict,
  }) async {
    try {
      // Siapkan body request (sesuaikan dengan kebutuhan API Anda)
      final requestBody = jsonEncode({
        'last_historical_date': lastHistoricalDate, // Kirim tanggal terakhir
        'days_to_predict': daysToPredict,
      });

      final response = await http.post(
        Uri.parse(_apiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        // Asumsi API mengembalikan JSON seperti: {"predictions": [10.0, 12.5, 11.0]}
        List<double> predictions = List<double>.from(
          responseData['predictions'] ?? [],
        );
        return ApiPredictionResult(predictedQuantities: predictions);
      } else {
        // Tangani error dari API
        print('API Error: ${response.statusCode} - ${response.body}');
        return ApiPredictionResult(
          predictedQuantities: [],
          success: false,
          errorMessage:
              'Gagal mendapatkan prediksi dari API: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Tangani error koneksi atau lainnya
      print('Error calling prediction API: $e');
      return ApiPredictionResult(
        predictedQuantities: [],
        success: false,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }
}
