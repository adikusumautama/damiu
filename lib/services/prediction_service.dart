// lib/services/prediction_service.dart
import 'dart:convert'; // Untuk jsonDecode
import 'package:http/http.dart' as http;
import 'package:damiu/models/prediction_result_model.dart'; // Import model prediksi baru

class PredictionService {
  // URL API Backend Anda (ganti dengan URL sebenarnya)
  // final String _apiBaseUrl = 'http://127.0.0.1:5000/predict'; // SALAH jika dari emulator/HP
  // Gunakan IP ini jika menjalankan Flutter di Emulator Android dan Flask di PC yang sama
  // final String _apiBaseUrl = 'http://10.0.2.2:5000/predict';
  // Gunakan IP lokal PC Anda jika menjalankan Flutter di HP pada WiFi yang sama (ganti dengan IP Anda)
  // final String _apiBaseUrl = 'http://192.168.100.72:5000/predict'; // GANTI DENGAN IP LOKAL PC ANDA
  final String _apiBaseUrl = 'http://10.5.50.129:5000/predict'; // GANTI DENGAN IP LOKAL PC ANDA
  // final String _apiBaseUrl = 'http://192.16.4.196:5000/predict'; 



  // Fungsi untuk mendapatkan prediksi dari API
  // `daysToPredict` adalah berapa hari ke depan yang ingin diprediksi
  Future<ApiPredictionResult> getPredictionsFromApi({
    // daysToPredict parameter diabaikan oleh API Flask yang baru
    // int daysToPredict = 1, // Parameter ini tidak lagi relevan untuk API Flask yang diubah
    String dataSource = 'firestore', // Tambahkan parameter dataSource, default ke firestore
  }) async {
    try {
      // Siapkan body request (sesuaikan dengan kebutuhan API Anda)
      final requestBody = jsonEncode({
        'data_source': dataSource, // Kirim parameter dataSource
      });

      final response = await http.post(
        Uri.parse(_apiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ApiPredictionResult.fromJson(data);
      } else {
        // Handle non-200 status codes, which might contain an error message
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          return ApiPredictionResult(
            success: false,
            errorMessage: errorData['error'] ?? 'Unknown API error (Status: ${response.statusCode})',
          );
        } catch (e) { // Tangani jika respons bukan JSON atau formatnya tidak sesuai
          return ApiPredictionResult(
            success: false,
            errorMessage: 'Failed to parse error response (Status: ${response.statusCode}): $e',
          );
        }
      }
    } catch (e) {
      // Tangani error koneksi atau lainnya
      print('Error calling prediction API: $e');
      // Menggunakan ApiPredictionResult dengan success: false untuk error koneksi
      return ApiPredictionResult(
        success: false,
        errorMessage: 'Terjadi kesalahan koneksi: $e',
      );
    }
  }
}
