import 'dart:convert'; 
import 'package:http/http.dart' as http;
import 'package:damiu/models/prediction_result_model.dart';

class PredictionService {

  final String _apiBaseUrl = 'http://10.138.156.78:5000/predict';

  Future<ApiPredictionResult> getPredictionsFromApi({
    String dataSource = 'firestore', 
  }) async {
    try {
      final requestBody = jsonEncode({
        'data_source': dataSource,
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
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          return ApiPredictionResult(
            success: false,
            errorMessage: errorData['error'] ?? 'Unknown API error (Status: ${response.statusCode})',
          );
        } catch (e) { 
          return ApiPredictionResult(
            success: false,
            errorMessage: 'Failed to parse error response (Status: ${response.statusCode}): $e',
          );
        }
      }
    } catch (e) {
      print('Error calling prediction API: $e');
      return ApiPredictionResult(
        success: false,
        errorMessage: 'Terjadi kesalahan koneksi: $e',
      );
    }
  }
}
