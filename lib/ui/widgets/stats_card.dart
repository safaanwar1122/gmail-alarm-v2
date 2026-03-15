import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/health_monitor.dart';

/// Stats card showing health metrics
class StatsCard extends StatelessWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadMetrics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final metrics = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics),
                    const SizedBox(width: 8),
                    Text(
                      'Statistics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      context,
                      'Total Scans',
                      metrics['total_scans'].toString(),
                    ),
                    _buildStat(
                      context,
                      'Failed',
                      metrics['failed_scans'].toString(),
                    ),
                    _buildStat(
                      context,
                      'Success Rate',
                      '${metrics['success_rate']}%',
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      context,
                      'Token Refreshes',
                      metrics['token_refreshes'].toString(),
                    ),
                    _buildStat(
                      context,
                      'Restarts',
                      metrics['restart_count'].toString(),
                    ),
                    _buildStat(
                      context,
                      'Uptime',
                      _formatUptime(metrics['uptime_seconds'] as int),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      return '${(seconds / 60).floor()}m';
    } else {
      return '${(seconds / 3600).floor()}h';
    }
  }

  Future<Map<String, dynamic>> _loadMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final monitor = HealthMonitor(prefs);
    return monitor.getMetrics();
  }
}
