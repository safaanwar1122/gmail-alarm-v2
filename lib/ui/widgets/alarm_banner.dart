import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../providers/alarm_provider.dart';
import '../../services/alarm_manager.dart';
import '../../config/constants.dart';

/// Banner shown when alarm is ringing
class AlarmBanner extends StatelessWidget {
  const AlarmBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (context, alarm, _) {
        if (!alarm.isRinging) {
          return const SizedBox.shrink();
        }

        return Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 40,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ALARM RINGING!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          Text(
                            'Matching emails found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _dismissAlarm(context),
                  icon: const Icon(Icons.stop),
                  label: const Text('DISMISS ALARM'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _dismissAlarm(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = FlutterLocalNotificationsPlugin();
      final alarmManager = AlarmManager(prefs, notifications);

      await alarmManager.initialize();

      // Get dismissed email IDs from last matched emails
      final seenIds = prefs.getStringList(AppConstants.kSeenIds) ?? [];
      final emailIds = seenIds.map((e) => e.split('|').first).toList();

      await alarmManager.dismissAlarm(emailIds);

      if (context.mounted) {
        context.read<AlarmProvider>().updateRingingState(false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm dismissed'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss alarm: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
