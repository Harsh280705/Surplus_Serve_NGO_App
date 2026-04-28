// lib/screens/impact/impact_statistics_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class UserStats {
  final int donationCount;
  final int peopleHelped;
  final double kgSaved;
  final int completedDonations;
  final int pendingDonations;

  UserStats({
    this.donationCount = 0,
    this.peopleHelped = 0,
    this.kgSaved = 0.0,
    this.completedDonations = 0,
    this.pendingDonations = 0,
  });
}

class ImpactStatisticsPage extends StatefulWidget {
  const ImpactStatisticsPage({super.key});

  @override
  State<ImpactStatisticsPage> createState() => _ImpactStatisticsPageState();
}

class _ImpactStatisticsPageState extends State<ImpactStatisticsPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Impact Statistics'),
          backgroundColor: kPrimaryColor,
        ),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Impact Statistics'),
        backgroundColor: kPrimaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final userRole = userData['role'] ?? '';
          final isNgo = userRole == 'NGO';

          return StreamBuilder<QuerySnapshot>(
            stream: isNgo
                ? _firestoreService.getNgoConfirmedDonations(userId)
                : _firestoreService.getUserConfirmedDonations(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              UserStats stats = _calculateStats(snapshot, userId, isNgo);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(stats, isNgo),
                    const SizedBox(height: 24),
                    _buildPieChart(stats),
                    const SizedBox(height: 24),
                    _buildBarChart(stats),
                    const SizedBox(height: 24),
                    _buildDetailedStats(stats, isNgo),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  UserStats _calculateStats(
    AsyncSnapshot<QuerySnapshot> snapshot,
    String userId,
    bool isNgo,
  ) {
    if (!snapshot.hasData) {
      return UserStats();
    }

    int totalDonations = 0;
    int peopleHelped = 0;
    int completed = 0;
    int pending = 0;
    const double kgPerServing = 0.5;

    for (var doc in snapshot.data!.docs) {
      final data = doc.data() as Map<String, dynamic>;

      final isConfirmed = data['confirmedByEventManager'] == true;

      if (isNgo) {
        final declinedBy = (data['declinedBy'] as List?) ?? [];
        if (declinedBy.contains(userId)) continue;

        if (isConfirmed) {
          totalDonations++;
          completed++;
          peopleHelped +=
              int.tryParse(data['servingCapacity']?.toString() ?? '0') ?? 0;
        } else if (data['status'] == 'Accepted') {
          pending++;
        }
      } else {
        if (isConfirmed) {
          totalDonations++;
          completed++;
          peopleHelped +=
              int.tryParse(data['servingCapacity']?.toString() ?? '0') ?? 0;
        } else if (data['status'] == 'Accepted') {
          pending++;
        }
      }
    }

    return UserStats(
      donationCount: totalDonations,
      peopleHelped: peopleHelped,
      kgSaved: peopleHelped * kgPerServing,
      completedDonations: completed,
      pendingDonations: pending,
    );
  }

  Widget _buildSummaryCards(UserStats stats, bool isNgo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isNgo ? 'Your NGO Impact' : 'Your Donation Impact',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Confirmed\nDonations',
                stats.donationCount.toString(),
                Icons.check_circle_rounded,
                kPrimaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'People\nHelped',
                stats.peopleHelped.toString(),
                Icons.people_rounded,
                kSecondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Food Saved\n(Kg)',
                stats.kgSaved.toStringAsFixed(1),
                Icons.eco_rounded,
                Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pending\nConfirmation',
                stats.pendingDonations.toString(),
                Icons.pending_rounded,
                Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: kTextSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(UserStats stats) {
    final total = stats.completedDonations + stats.pendingDonations;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_chart_outlined, size: 48, color: kTextSecondary),
            const SizedBox(height: 12),
            const Text(
              'No donation data yet',
              style: TextStyle(color: kTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Donation Status Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  if (stats.completedDonations > 0)
                    PieChartSectionData(
                      value: stats.completedDonations.toDouble(),
                      title: '${stats.completedDonations}\nCompleted',
                      color: Colors.green.shade600,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (stats.pendingDonations > 0)
                    PieChartSectionData(
                      value: stats.pendingDonations.toDouble(),
                      title: '${stats.pendingDonations}\nPending',
                      color: Colors.orange.shade600,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(UserStats stats) {
    // Show chart even if values are zero (bars will be tiny but visible)
    final maxValue = [
      stats.donationCount.toDouble(),
      stats.peopleHelped.toDouble(),
      stats.kgSaved,
    ].reduce((a, b) => a > b ? a : b);

    final maxY = (maxValue > 0 ? maxValue * 1.2 : 10).toDouble(); // fallback to 10 if all zero

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Impact Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Donations', style: TextStyle(fontSize: 10));
                          case 1:
                            return const Text('People', style: TextStyle(fontSize: 10));
                          case 2:
                            return const Text('Kg Saved', style: TextStyle(fontSize: 10));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: stats.donationCount.toDouble(),
                        color: kPrimaryColor,
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: stats.peopleHelped.toDouble(),
                        color: kSecondaryColor,
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: stats.kgSaved,
                        color: Colors.green.shade600,
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(UserStats stats, bool isNgo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Total Confirmed Donations',
            stats.donationCount.toString(),
            Icons.check_circle,
            kPrimaryColor,
          ),
          _buildDetailRow(
            'Total People Helped',
            stats.peopleHelped.toString(),
            Icons.people,
            kSecondaryColor,
          ),
          _buildDetailRow(
            'Total Food Saved (Kg)',
            stats.kgSaved.toStringAsFixed(2),
            Icons.eco,
            Colors.green.shade600,
          ),
          _buildDetailRow(
            'Completed Donations',
            stats.completedDonations.toString(),
            Icons.done_all,
            Colors.green.shade600,
          ),
          _buildDetailRow(
            'Pending Confirmation',
            stats.pendingDonations.toString(),
            Icons.pending,
            Colors.orange.shade600,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isNgo
                        ? 'Stats update when Event Manager confirms food delivery'
                        : 'Stats update when you confirm NGO received the food',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}