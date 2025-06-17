import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/linear_regression_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class PredictionChartWidget extends StatelessWidget {
  final List<DailySale> historicalSales;
  final LinearRegressionModel regressionModel;
  final int daysToPredict;

  const PredictionChartWidget({
    super.key,
    required this.historicalSales,
    required this.regressionModel,
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
    List<FlSpot> regressionLineSpots = [];

    final DateTime startDate = historicalSales.first.date;

    for (var sale in historicalSales) {
      final double dayIndex = sale.date.difference(startDate).inDays.toDouble();
      historicalSpots.add(FlSpot(dayIndex, sale.quantity.toDouble()));
    }

    final double lastHistoricalDayIndex =
        historicalSales.last.date.difference(startDate).inDays.toDouble();
    final double totalChartDays = lastHistoricalDayIndex + daysToPredict;

    if (regressionModel.slope != 0 || regressionModel.intercept != 0) {
      for (double i = 0; i <= totalChartDays; i++) {
        final double modelInputDayIndex = i + 1;
        regressionLineSpots.add(
          FlSpot(i, regressionModel.predict(modelInputDayIndex)),
        );
      }
    }

    if (regressionModel.slope != 0 || regressionModel.intercept != 0) {
      final double lastHistoricalModelInputDay =
          historicalSales.last.date.difference(startDate).inDays.toDouble() + 1.0;
      for (int i = 1; i <= daysToPredict; i++) {
        final double dayIndexRelativeToStart = lastHistoricalDayIndex + i;
        final double modelInputDayIndex =
            lastHistoricalModelInputDay + i.toDouble();
        final double predictedQty = regressionModel.predict(modelInputDayIndex);
        predictedSpots.add(
          FlSpot(dayIndexRelativeToStart, predictedQty.roundToDouble()),
        );
      }
    }

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

    final double effectiveMaxX = totalChartDays == 0 && historicalSpots.length == 1 ? 1 : totalChartDays;
    final double calculatedChartWidth =
        (effectiveMaxX * minSpacePerDayUnit) + leftReservedSpace + rightPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth, // jangan lebih kecil dari lebar layar
              maxWidth: calculatedChartWidth, // panjang berdasarkan jumlah data
            ),
            child: SizedBox(
              height: 500,
              child: Container(
                padding: const EdgeInsets.only(
                  top: 100,
                  left: 0,
                  right: 50,
                  bottom: 10,
                ),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: effectiveMaxX,
                    backgroundColor: const Color(0xfff0f0f0),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: true,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.3),
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
                            final date = startDate.add(Duration(days: value.toInt()));
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
                      border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: historicalSpots,
                        isCurved: true,
                        color: Colors.blue.shade700,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: historicalSpots.length < 200,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(radius: 3, color: Colors.blue.shade900, strokeWidth: 1, strokeColor: Colors.white),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      if (regressionLineSpots.isNotEmpty)
                        LineChartBarData(
                          spots: regressionLineSpots,
                          isCurved: true,
                          color: Colors.green.shade600.withOpacity(0.8),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          dashArray: [5, 5],
                        ),
                      if (predictedSpots.isNotEmpty)
                        LineChartBarData(
                          spots: predictedSpots,
                          isCurved: true,
                          color: Colors.red.shade600,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.red.withOpacity(0.2),
                          ),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final flSpot = barSpot;
                            final date = startDate.add(Duration(days: flSpot.x.toInt()));
                            final formattedDate = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date);
                            String seriesName = '';
                            Color seriesColor = Colors.white;

                            if (barSpot.barIndex == 0) {
                              seriesName = 'Historis: ';
                              seriesColor = Colors.blue;
                            } else {
                              if (regressionLineSpots.isNotEmpty) {
                                if (barSpot.barIndex == 1) {
                                  seriesName = 'Regresi: ';
                                  seriesColor = Colors.green;
                                } else if (barSpot.barIndex == 2 && predictedSpots.isNotEmpty) {
                                  seriesName = 'Prediksi: ';
                                  seriesColor = Colors.red;
                                }
                              } else if (predictedSpots.isNotEmpty) {
                                if (barSpot.barIndex == 1) {
                                  seriesName = 'Prediksi: ';
                                  seriesColor = Colors.red;
                                }
                              }
                            }

                            final displayY = flSpot.y < 0 ? 0 : flSpot.y;
                            return LineTooltipItem(
                              '$seriesName${displayY.toStringAsFixed(0)} galon\n',
                              TextStyle(
                                color: seriesColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: formattedDate,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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


// Widget terpisah untuk menampilkan legenda grafik
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(color: Colors.blue, text: 'Historis'),
          SizedBox(width: 16),
          _LegendItem(color: Colors.green, text: 'Regresi'),
          SizedBox(width: 16),
          _LegendItem(color: Colors.red, text: 'Prediksi'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
