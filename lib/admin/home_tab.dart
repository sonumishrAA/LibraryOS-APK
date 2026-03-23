import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../globals.dart';
import '../login_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    setState(() => _isLoading = true);
    final jwt = await storage.read(key: 'admin_jwt');

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/get-dashboard-stats?scope=admin'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (res.statusCode == 401) {
        await storage.delete(key: 'admin_jwt');
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
        return;
      }

      if (res.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: adminAccentColor));
    }

    if (_stats == null) {
      return Center(child: Text('Failed to load stats', style: GoogleFonts.plusJakartaSans(color: adminTextSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Stat Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total Libraries', _stats!['total_libraries'].toString(), Colors.white),
              _buildStatCard('Active', _stats!['active_libraries'].toString(), const Color(0xFF22C55E)),
              _buildStatCard('Grace Period', _stats!['grace_libraries'].toString(), adminAccentColor),
              _buildStatCard('This Month', '₹${_stats!['monthly_revenue']}', adminAccentColor),
            ],
          ),

          const SizedBox(height: 32),

          // Expiring Soon
          if (_stats!['expiring_libraries'] != null && (_stats!['expiring_libraries'] as List).isNotEmpty) ...[
            _buildSectionHeader('⚠️ Expiring Soon', _stats!['expiring_libraries'].length),
            const SizedBox(height: 12),
            ...(_stats!['expiring_libraries'] as List).map((lib) => _buildExpiringRow(lib)),
            const SizedBox(height: 32),
          ],

          // Growth Overview
          Text('Last 6 Months', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildChart(),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.plusJakartaSans(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.plusJakartaSans(color: adminTextSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(color: adminAccentColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: adminAccentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: GoogleFonts.plusJakartaSans(color: adminAccentColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildExpiringRow(Map<String, dynamic> lib) {
    final expiry = DateTime.parse(lib['subscription_end']);
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final statusColor = daysLeft < 3 ? Colors.red : (daysLeft < 7 ? adminAccentColor : adminTextSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: adminSurfaceColor,
        border: Border(left: BorderSide(color: Colors.red, width: 3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lib['name'], style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(DateFormat('dd MMM yyyy').format(expiry), style: GoogleFonts.plusJakartaSans(color: adminTextSecondary, fontSize: 12)),
            ],
          ),
          Text('$daysLeft days left', style: GoogleFonts.plusJakartaSans(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final List<dynamic> chartData = _stats!['chart_data'] ?? [];
    if (chartData.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('No chart data')));

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (chartData.map((e) => e['registrations']).reduce((a, b) => a > b ? a : b) as int).toDouble() + 5,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < chartData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        chartData[index]['name'].toString().length > 3 
                            ? chartData[index]['name'].toString().substring(0, 3).toUpperCase()
                            : chartData[index]['name'].toString().toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(color: adminTextSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.plusJakartaSans(color: adminTextSecondary, fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => const FlLine(color: adminBorderColor, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: chartData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['registrations'] as int).toDouble(),
                  color: Colors.blueAccent,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: (entry.value['revenue'] / 1000).toDouble(), // Scale revenue for chart
                  color: const Color(0xFF22C55E),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.blueAccent, 'Registrations'),
        const SizedBox(width: 16),
        _buildLegendItem(const Color(0xFF22C55E), 'Revenue (k)'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(color: adminTextSecondary, fontSize: 11)),
      ],
    );
  }
}
