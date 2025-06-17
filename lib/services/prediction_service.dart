// lib/services/prediction_service.dart
import 'package:damiu/models/linear_regression_model.dart';

class PredictionService {
  // Input data: List<Map<String, double>> dengan keys 'day' (x) dan 'quantity' (y)
  LinearRegressionModel calculateLinearRegression(List<Map<String, double>> data) {
    if (data.length < 2) {
      // Tidak cukup data untuk regresi yang berarti
      print("Peringatan: Data tidak cukup untuk regresi linier (<2 poin). Mengembalikan model default.");
      return LinearRegressionModel(slope: 0, intercept: 0);
    }

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    int n = data.length;

    for (var point in data) {
      // Pastikan key ada dan tidak null sebelum diakses
      double x = point['day'] ?? 0; // Default ke 0 jika null, idealnya data sudah bersih
      double y = point['quantity'] ?? 0;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    double denominator = (n * sumX2) - (sumX * sumX);

    if (denominator == 0) {
      print("Peringatan: Denominator dalam perhitungan slope adalah nol. Cek variasi data X.");
      double averageY = n > 0 ? sumY / n : 0;
      return LinearRegressionModel(slope: 0, intercept: averageY);
    }

    double slope = (n * sumXY - sumX * sumY) / denominator;
    double intercept = (sumY - slope * sumX) / n;
    return LinearRegressionModel(slope: slope, intercept: intercept);
  }
}