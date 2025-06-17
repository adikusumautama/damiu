// lib/services/data_service.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:damiu/models/daily_sale_model.dart';

class DataService {
  Future<List<DailySale>> loadSalesDataFromCsv(String assetPath) async {
    try {
      final rawCsv = await rootBundle.loadString(assetPath);
      List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n', fieldDelimiter: ',').convert(rawCsv);
      List<DailySale> salesData = [];

      // File CSV memiliki 2 baris header:
      // Baris 1: "Data Galon Terjual,,"
      // Baris 2: "Tanggal,Hari,Galon Terjual"
      // Data aktual dimulai dari baris ke-3 (indeks 2).
      for (int i = 2; i < csvTable.length; i++) { // Mulai dari indeks 2 untuk melewati 2 baris header
        final row = csvTable[i];
        // Pastikan jumlah kolom sesuai dan data bisa di-parse
        // Asumsi format CSV: Tanggal, Hari, Galon Terjual
        if (row.length >= 3) {
          final String dateString = row[0].toString();
          final int? quantity = int.tryParse(row[2].toString()); // Ambil kuantitas dari kolom ketiga

          try {
            final DateTime date = DateTime.parse(dateString); // Parse tanggal dari string

            if (quantity != null) {
            salesData.add(DailySale(
              date: date, // Gunakan tanggal dari CSV
              dayOfWeek: date.weekday, // Ambil hari dari tanggal yang diparse
              deliveryCount: 0, // Tambahkan nilai default untuk deliveryCount dari CSV
              quantity: quantity,
              isSynced: true, // Anggap data CSV sudah "final" atau "synced"
            ));
            } else { // Kuantitas null
               print('Peringatan: Kuantitas di baris CSV ${i+1} (data baris ${i-1}) tidak bisa di-parse: ${row[2]}');
            }
          } on FormatException catch (e) { // Gagal parse tanggal
            print('Peringatan: Format tanggal salah di baris CSV ${i+1} (data baris ${i-1}): ${row[0]}. Error: $e');
          }
        } else {
           print('Peringatan: Baris CSV ${i+1} (data baris ${i-1}) tidak memiliki cukup kolom: $row');
        }
      }
      return salesData;
    } catch (e) {
      print('Error loading DailySale data from CSV ($assetPath): $e');
      return [];
    }
  }
}
