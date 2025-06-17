// lib/models/linear_regression_model.dart
class LinearRegressionModel {
  final double slope;
  final double intercept;

  LinearRegressionModel({required this.slope, required this.intercept});

  // Fungsi untuk memprediksi Y berdasarkan X
  double predict(double x) {
    // Jika slope dan intercept 0 (misal, tidak cukup data), prediksi bisa 0 atau rata-rata Y
    if (slope == 0 && intercept == 0) return 0; // Atau handle kasus ini secara spesifik
    return slope * x + intercept;
  }
}
