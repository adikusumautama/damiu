import 'package:intl/intl.dart'; // Import DateFormat

class SingleDayPrediction {
  final DateTime date;
  final int predictedQuantity;
  final List<double>? confidenceRange; // Optional confidence range

  SingleDayPrediction({
    required this.date,
    required this.predictedQuantity,
    this.confidenceRange,
  });

  factory SingleDayPrediction.fromJson(Map<String, dynamic> json) {
    // Pastikan parsing tanggal menggunakan format yang benar dari API
    // API mengembalikan "YYYY-MM-DD"
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return SingleDayPrediction(
      date: formatter.parse(json['Tanggal']),
      predictedQuantity: (json['Prediksi Galon'] as num).round(), // API returns double, round it
      confidenceRange: json['Confidence Range'] != null
          ? List<double>.from(json['Confidence Range'])
          : null,
    );
  }
}

class ApiPredictionResult {
  final String? lastKnownDataDate; // Tanggal data historis terakhir dari API
  final SingleDayPrediction? predictionForNextDay; // Objek prediksi untuk besok
  final bool success;
  final String? errorMessage; // Pesan error dari API

  ApiPredictionResult({
    this.lastKnownDataDate,
    this.predictionForNextDay,
    required this.success,
    this.errorMessage,
  });

  factory ApiPredictionResult.fromJson(Map<String, dynamic> json) {
    // Handle the new structure for success
    if (json.containsKey('prediction_for_next_day')) {
      return ApiPredictionResult(
        lastKnownDataDate: json['last_known_data_date'],
        predictionForNextDay: SingleDayPrediction.fromJson(json['prediction_for_next_day']),
        success: true,
        errorMessage: null,
      );
    } else if (json.containsKey('error')) {
      // Handle the error structure
      return ApiPredictionResult(
        success: false,
        errorMessage: json['error'],
      );
    } else {
      // Handle unexpected structure
      return ApiPredictionResult(
        success: false,
        errorMessage: 'Unexpected API response format',
      );
    }
  }
}

