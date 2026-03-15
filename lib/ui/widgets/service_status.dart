import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';

/// Service status card
class ServiceStatus extends StatelessWidget {
  const ServiceStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceProvider>(
      builder: (context, service, _) {
        final healthAge = service.getHealthCheckAge();
        final isHealthy = service.isHealthy();

        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (service.isStarting) {
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_empty;
          statusText = 'Starting...';
        } else if (service.isRunning && isHealthy) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'Running';
        } else if (service.isRunning && !isHealthy) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning;
          statusText = 'Unhealthy';
        } else {
          statusColor = Colors.red;
          statusIcon = Icons.error;
          statusText = 'Stopped';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      'Background Service',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (healthAge != null)
                      Text(
                        'Last heartbeat: ${_formatAge(healthAge)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                if (service.restartCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Restart count: ${service.restartCount}',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!service.isRunning)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: service.isStarting
                              ? null
                              : () => _startService(context),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Service'),
                        ),
                      ),
                    if (service.isRunning) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _stopService(context),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Service'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAge(Duration age) {
    if (age.inSeconds < 60) {
      return '${age.inSeconds}s ago';
    } else if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago';
    } else {
      return '${age.inHours}h ago';
    }
  }

  Future<void> _startService(BuildContext context) async {
    final service = context.read<ServiceProvider>();
    final started = await service.startService();

    if (!started && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start service'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopService(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Service'),
        content: const Text('Are you sure you want to stop the background service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<ServiceProvider>().stopService();
    }
  }
}
