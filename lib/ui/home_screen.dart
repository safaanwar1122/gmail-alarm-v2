import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/alarm_provider.dart';
import '../providers/service_provider.dart';
import '../config/constants.dart';
import 'widgets/alarm_banner.dart';
import 'widgets/keyword_list.dart';
import 'widgets/service_status.dart';
import 'widgets/stats_card.dart';

/// Main home screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Alarm'),
        actions: [
          // Test Mode Toggle
          Consumer<AlarmProvider>(
            builder: (context, alarm, _) {
              return FutureBuilder<bool>(
                future: _getTestMode(),
                builder: (context, snapshot) {
                  final testMode = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      testMode ? Icons.bug_report : Icons.bug_report_outlined,
                      color: testMode ? Colors.orange : null,
                    ),
                    tooltip: 'Test Mode',
                    onPressed: () => _toggleTestMode(context),
                  );
                },
              );
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
          // Sign Out
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshState(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Alarm Banner (shows when ringing)
              const AlarmBanner(),

              // User Info Card
              _buildUserCard(context),
              const SizedBox(height: 16),

              // Service Status
              const ServiceStatus(),
              const SizedBox(height: 16),

              // Stats Card
              const StatsCard(),
              const SizedBox(height: 16),

              // Alarm Toggle
              _buildAlarmToggle(context),
              const SizedBox(height: 16),

              // Scan Interval
              _buildScanIntervalSlider(context),
              const SizedBox(height: 24),

              // Keywords Section
              _buildKeywordsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: auth.userPhotoUrl != null
                      ? NetworkImage(auth.userPhotoUrl!)
                      : null,
                  child: auth.userPhotoUrl == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.userName ?? 'User',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        auth.userEmail ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlarmToggle(BuildContext context) {
    return Consumer2<AlarmProvider, ServiceProvider>(
      builder: (context, alarm, service, _) {
        return Card(
          child: SwitchListTile(
            title: const Text('Alarm Enabled'),
            subtitle: Text(
              alarm.isEnabled
                  ? 'Monitoring your inbox'
                  : 'Alarm is disabled',
            ),
            value: alarm.isEnabled,
            onChanged: (value) => _toggleAlarm(context, value),
            secondary: Icon(
              alarm.isEnabled ? Icons.alarm_on : Icons.alarm_off,
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanIntervalSlider(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (context, alarm, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Interval',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${alarm.scanIntervalMinutes} min',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Slider(
                  value: alarm.scanIntervalMinutes.toDouble(),
                  min: AppConstants.minScanInterval.inMinutes.toDouble(),
                  max: AppConstants.maxScanInterval.inMinutes.toDouble(),
                  divisions: 59,
                  label: '${alarm.scanIntervalMinutes} min',
                  onChanged: (value) {
                    alarm.setScanInterval(value.toInt());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeywordsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keywords',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Add keywords to monitor in your emails',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),

        // Add Keyword Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: 'New keyword',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => _addKeyword(context, value),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _addKeyword(context, _keywordController.text),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Keywords List
        const KeywordList(),
      ],
    );
  }

  Future<void> _toggleAlarm(BuildContext context, bool enabled) async {
    final alarm = context.read<AlarmProvider>();
    final service = context.read<ServiceProvider>();

    await alarm.setEnabled(enabled);

    if (enabled && !service.isRunning) {
      // Start service when alarm is enabled
      final started = await service.startService();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start background service'),
          ),
        );
      }
    }
  }

  Future<void> _addKeyword(BuildContext context, String keyword) async {
    if (keyword.trim().isEmpty) return;

    final alarm = context.read<AlarmProvider>();
    await alarm.addKeyword(keyword.trim());
    _keywordController.clear();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = context.read<ServiceProvider>();
      await service.stopService();
      
      final auth = context.read<AuthProvider>();
      await auth.signOut();
    }
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear Dismissed Emails'),
              onTap: () {
                context.read<AlarmProvider>().clearDismissedEmails();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dismissed emails cleared'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Restart Service'),
              onTap: () async {
                Navigator.of(context).pop();
                final service = context.read<ServiceProvider>();
                await service.stopService();
                await Future.delayed(const Duration(seconds: 2));
                await service.startService();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshState(BuildContext context) async {
    context.read<AlarmProvider>().refresh();
  }

  Future<bool> _getTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.kTestMode) ?? false;
  }

  Future<void> _toggleTestMode(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getBool(AppConstants.kTestMode) ?? false;
    await prefs.setBool(AppConstants.kTestMode, !current);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !current
                ? 'Test mode enabled (token expires in 10s)'
                : 'Test mode disabled',
          ),
        ),
      );
      setState(() {});
    }
  }
}
