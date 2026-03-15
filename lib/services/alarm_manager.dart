import 'package:alarm/alarm.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/email_match.dart';
import '../utils/logger.dart';

/// Manages alarm triggering and dismissal
class AlarmManager {
  static final _logger = Logger('ALARM');
  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _notifications;

  bool _isInitialized = false;
  bool _isRinging = false;

  AlarmManager(this._prefs, this._notifications);

  /// Initialize alarm system
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _logger.info('INIT', 'Initializing alarm manager');

      // Initialize Alarm plugin
      await Alarm.init();

      // Initialize notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channel (Android)
      const androidChannel = AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _isInitialized = true;
      _logger.info('INIT', 'Alarm manager initialized successfully');
      return true;
    } catch (e, stack) {
      _logger.exception('INIT', 'Failed to initialize alarm manager', e, stack);
      return false;
    }
  }

  /// Trigger alarm for matched emails
  Future<void> triggerAlarm(List<EmailMatch> matches) async {
    if (!_isInitialized) {
      _logger.warn('TRIGGER', 'Alarm manager not initialized');
      return;
    }

    if (matches.isEmpty) {
      _logger.warn('TRIGGER', 'No matches to trigger alarm for');
      return;
    }

    if (_isRinging) {
      _logger.info('TRIGGER', 'Alarm already ringing, skipping');
      return;
    }

    try {
      _logger.info('TRIGGER', 'Triggering alarm', {
        'matches': matches.length,
      });

      _isRinging = true;
      await _prefs.setBool(AppConstants.kAlarmRinging, true);

      // Store matched emails for UI display
      final matchesJson = matches.map((m) => m.toJson()).toList();
      await _prefs.setString(
        AppConstants.kLastMatchedEmails,
        matchesJson.toString(),
      );

      // Set alarm with looping sound
      final alarmSettings = AlarmSettings(
        id: AppConstants.alarmNotificationId,
        dateTime: DateTime.now(),
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volume: 0.8,
        fadeDuration: 3.0,
        notificationTitle: 'Gmail Alarm',
        notificationBody: _buildNotificationBody(matches),
        enableNotificationOnKill: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);

      // Also show notification in case alarm fails
      await _showNotification(matches);

      _logger.info('TRIGGER', 'Alarm triggered successfully', {
        'matches': matches.length,
      });
    } catch (e, stack) {
      _logger.exception('TRIGGER', 'Failed to trigger alarm', e, stack);
      
      // Fallback to notification only
      try {
        await _showNotification(matches);
      } catch (e2) {
        _logger.exception('TRIGGER', 'Fallback notification also failed', e2);
      }
    }
  }

  /// Dismiss alarm
  Future<void> dismissAlarm(List<String> emailIds) async {
    if (!_isRinging) {
      _logger.info('DISMISS', 'No alarm ringing');
      return;
    }

    try {
      _logger.info('DISMISS', 'Dismissing alarm', {
        'email_ids': emailIds.length,
      });

      // Stop alarm
      await Alarm.stop(AppConstants.alarmNotificationId);

      // Cancel notification
      await _notifications.cancel(AppConstants.alarmNotificationId);

      // Mark emails as dismissed
      await _markEmailsAsDismissed(emailIds);

      _isRinging = false;
      await _prefs.setBool(AppConstants.kAlarmRinging, false);

      _logger.info('DISMISS', 'Alarm dismissed successfully');
    } catch (e, stack) {
      _logger.exception('DISMISS', 'Failed to dismiss alarm', e, stack);
    }
  }

  /// Check if alarm is currently ringing
  bool isRinging() {
    return _isRinging || (_prefs.getBool(AppConstants.kAlarmRinging) ?? false);
  }

  /// Show notification
  Future<void> _showNotification(List<EmailMatch> matches) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      AppConstants.alarmNotificationId,
      'Gmail Alarm - ${matches.length} matches found!',
      _buildNotificationBody(matches),
      notificationDetails,
    );
  }

  /// Build notification body text
  String _buildNotificationBody(List<EmailMatch> matches) {
    if (matches.isEmpty) return 'No matches';
    if (matches.length == 1) {
      final match = matches.first;
      return '${match.subject} - ${match.from}';
    }
    return '${matches.first.subject} and ${matches.length - 1} more';
  }

  /// Mark emails as dismissed
  Future<void> _markEmailsAsDismissed(List<String> emailIds) async {
    final dismissed = _prefs.getStringList(AppConstants.kDismissedIds) ?? [];
    dismissed.addAll(emailIds);
    await _prefs.setStringList(AppConstants.kDismissedIds, dismissed);
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    _logger.info('NOTIFICATION', 'Notification tapped', {
      'id': response.id,
      'payload': response.payload,
    });
    // App will handle showing dismiss UI
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      if (_isRinging) {
        await Alarm.stop(AppConstants.alarmNotificationId);
        _isRinging = false;
      }
      _logger.info('DISPOSE', 'Alarm manager disposed');
    } catch (e) {
      _logger.exception('DISPOSE', 'Error during disposal', e);
    }
  }
}
