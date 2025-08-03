import 'package:damiu/models/daily_sale_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PredictionChartWidget extends StatelessWidget {
  final List<DailySale> historicalSales;
  final List<double> predictedQuantities;
  final int daysToPredict;

  const PredictionChartWidget({
    super.key,
    required this.historicalSales,
    required this.predictedQuantities,
    required this.daysToPredict,
  });

  @override
  Widget build(BuildContext context) {
    if (historicalSales.isEmpty) {
      return const Center(
        child: Text('Tidak ada data untuk ditampilkan pada grafik.'),
      );
    }

    List<FlSpot> historicalSpots = [];
    List<FlSpot> predictedSpots = [];

    final DateTime startDate = historicalSales.first.date;

    for (var sale in historicalSales) {
      final double dayIndex = sale.date.difference(startDate).inDays.toDouble();
      historicalSpots.add(FlSpot(dayIndex, sale.quantity.toDouble()));
    }

    final double lastHistoricalDayIndex = historicalSales.last.date
        .difference(startDate)
        .inDays
        .toDouble();

    // Buat FlSpot untuk prediksi berdasarkan predictedQuantities dari API
    if (predictedQuantities.isNotEmpty) {
      for (int i = 1; i <= daysToPredict; i++) {
        final double dayIndexRelativeToStart = lastHistoricalDayIndex + i;
        if (i <= predictedQuantities.length) {
          predictedSpots.add(
            FlSpot(dayIndexRelativeToStart, predictedQuantities[i - 1]),
          );
        }
      }
    }

    // --- PERBAIKAN: Sambungkan garis historis dan prediksi ---
    final List<FlSpot> connectedPredictedSpots = predictedSpots.isNotEmpty
        ? [historicalSpots.last, ...predictedSpots]
        : [];

    final double totalChartDays = lastHistoricalDayIndex + daysToPredict;

    double bottomTitleInterval = 1.0;
    if (totalChartDays > 0) {
      if (totalChartDays <= 10)
        bottomTitleInterval = 1;
      else if (totalChartDays <= 35)
        bottomTitleInterval = 7;
      else if (totalChartDays <= 180)
        bottomTitleInterval = 30;
      else
        bottomTitleInterval = totalChartDays / 6;
    }

    const double leftReservedSpace = 40;
    const double rightPadding = 20;
    const double minSpacePerDayUnit = 25.0;

    final double effectiveMaxX =
        totalChartDays == 0 && historicalSpots.length == 1 ? 1 : totalChartDays;
    final double calculatedChartWidth =
        (effectiveMaxX * minSpacePerDayUnit) + leftReservedSpace + rightPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: calculatedChartWidth > constraints.maxWidth
                  ? calculatedChartWidth
                  : constraints.maxWidth, // jangan lebih kecil dari lebar layar
              maxWidth: calculatedChartWidth > constraints.maxWidth
                  ? calculatedChartWidth
                  : constraints.maxWidth, // panjang berdasarkan jumlah data
            ),
            child: SizedBox(
              height: 350,
              child: Container(
                padding: const EdgeInsets.only(top: 24, right: 24, bottom: 12),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: effectiveMaxX,
                    backgroundColor: Colors.transparent,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: true,
                      horizontalInterval: 10,
                      verticalInterval: bottomTitleInterval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: leftReservedSpace,
                          getTitlesWidget: (value, meta) {
                            if (value % 1 == 0) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return Container();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: bottomTitleInterval,
                          getTitlesWidget: (value, meta) {
                            if (value > effectiveMaxX) return Container();
                            final date = startDate.add(
                              Duration(days: value.toInt()),
                            );
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4,
                              child: Text(
                                DateFormat('dd MMM', 'id_ID').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: historicalSpots,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade400],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: historicalSpots.length < 100,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: Colors.blue,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade300.withOpacity(0.4),
                              Colors.blue.shade200.withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      if (predictedSpots.isNotEmpty)
                        LineChartBarData(
                          spots: connectedPredictedSpots,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade500,
                              Colors.deepPurple.shade300,
                            ],
                          ),
                          barWidth: 4,
                          dashArray: [8, 6],
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade300.withOpacity(0.4),
                                Colors.deepPurple.shade200.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        // --- PERBAIKAN: Tooltip yang lebih baik ---
                        tooltipBgColor: Colors.black.withOpacity(0.8),
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final flSpot = barSpot;
                            final date = startDate.add(
                              Duration(days: flSpot.x.toInt()),
                            );
                            final formattedDate = DateFormat(
                              'EEEE, dd MMM yyyy',
                              'id_ID',
                            ).format(date);
                            String seriesName = '';
                            TextStyle seriesTextStyle;

                            if (barSpot.barIndex == 0) {
                              seriesName = 'Historis';
                              seriesTextStyle = const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              );
                            } else if (barSpot.barIndex == 1) {
                              seriesName = 'Prediksi';
                              seriesTextStyle = const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              );
                            } else {
                              seriesName = 'Data';
                              seriesTextStyle = const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              );
                            }

                            final displayY = flSpot.y < 0 ? 0 : flSpot.y;

                            // Jangan tampilkan tooltip untuk titik sambungan
                            if (barSpot.barIndex == 1 &&
                                flSpot.x == lastHistoricalDayIndex) {
                              return null;
                            }

                            return LineTooltipItem(
                              '$seriesName\n',
                              seriesTextStyle,
                              children: [
                                TextSpan(
                                  text: '${displayY.toStringAsFixed(0)} Galon',
                                  style: seriesTextStyle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const TextSpan(text: '\n'),
                                TextSpan(
                                  text: formattedDate,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              textAlign: TextAlign.left,
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- PERBAIKAN: Widget legenda yang lebih baik ---
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: Colors.blue.shade500,
          text: 'Historis',
          isDashed: false,
        ),
        const SizedBox(width: 24),
        _LegendItem(
          color: Colors.deepPurple.shade400,
          text: 'Prediksi',
          isDashed: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final bool isDashed;

  const _LegendItem({
    required this.color,
    required this.text,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            // Jika ingin menampilkan garis putus-putus di legenda,
            // bisa menggunakan CustomPaint atau package `dotted_line`.
            // Untuk kesederhanaan, kita gunakan warna solid saja.
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
