/// App-wide constants
class AppConstants {
  // SharedPreferences Keys
  static const String kAlarmEnabled = 'alarm_enabled';
  static const String kScanInterval = 'scan_interval';
  static const String kKeywords = 'keywords';
  static const String kLastScanTime = 'last_scan_time';
  static const String kSeenIds = 'seen_ids';
  static const String kDismissedIds = 'dismissed_ids';
  static const String kAlarmRinging = 'alarm_ringing';
  static const String kServiceRunning = 'service_running';
  static const String kLastHealthCheck = 'last_health_check';
  static const String kTokenTimestamp = 'token_timestamp';
  static const String kRestartCount = 'restart_count';
  static const String kTotalScans = 'total_scans';
  static const String kFailedScans = 'failed_scans';
  static const String kTokenRefreshes = 'token_refreshes';
  static const String kLastMatchedEmails = 'last_matched_emails';

  // Token Management
  static const Duration tokenRefreshThreshold = Duration(minutes: 45);
  static const Duration tokenExpiryDuration = Duration(minutes: 60);
  static const int maxTokenRefreshRetries = 10;

  // Service Management
  static const Duration serviceHealthCheckInterval = Duration(seconds: 30);
  static const Duration serviceDeadThreshold = Duration(minutes: 5);
  static const int maxServiceRestarts = 5;
  static const Duration serviceRestartWindow = Duration(hours: 1);

  // Scanning
  static const Duration defaultScanInterval = Duration(minutes: 5);
  static const Duration minScanInterval = Duration(minutes: 1);
  static const Duration maxScanInterval = Duration(minutes: 60);
  static const int maxSeenEmails = 1000;
  static const Duration seenEmailRetention = Duration(hours: 2);

  // Retry Logic
  static const Duration initialRetryDelay = Duration(seconds: 1);
  static const int maxRetryAttempts = 10;
  static const double retryBackoffMultiplier = 2.0;

  // Google OAuth Scopes
  static const List<String> googleScopes = [
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
  ];

  // Logging
  static const String logLevelDebug = 'DEBUG';
  static const String logLevelInfo = 'INFO';
  static const String logLevelWarn = 'WARN';
  static const String logLevelError = 'ERROR';

  // Notifications
  static const String notificationChannelId = 'gmail_alarm_channel';
  static const String notificationChannelName = 'Gmail Alarm Notifications';
  static const String notificationChannelDescription =
      'Notifications for Gmail alarm triggers';
  static const int alarmNotificationId = 1001;

  // Background Service
  static const String backgroundServiceName = 'gmail_alarm_service';

  // Test Mode
  static const String kTestMode = 'test_mode';
  static const Duration testModeTokenExpiry = Duration(seconds: 10);
}
