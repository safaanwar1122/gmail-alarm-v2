import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// Monitors service health and emits heartbeat
class HealthMonitor {
  static final _logger = Logger('HEALTH');
  final SharedPreferences _prefs;

  Timer? _heartbeatTimer;
  DateTime? _startTime;
  bool _isRunning = false;

  HealthMonitor(this._prefs);

  /// Start health monitoring
  void start() {
    if (_isRunning) {
      _logger.warn('START', 'Health monitor already running');
      return;
    }

    try {
      _logger.info('START', 'Starting health monitor');

      _startTime = DateTime.now();
      _isRunning = true;

      // Emit heartbeat every minute
      _heartbeatTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _emitHeartbeat(),
      );

      // Emit initial heartbeat
      _emitHeartbeat();

      _logger.info('START', 'Health monitor started');
    } catch (e, stack) {
      _logger.exception('START', 'Failed to start health monitor', e, stack);
    }
  }

  /// Stop health monitoring
  void stop() {
    if (!_isRunning) {
      return;
    }

    try {
      _logger.info('STOP', 'Stopping health monitor');

      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _isRunning = false;

      _logger.info('STOP', 'Health monitor stopped');
    } catch (e, stack) {
      _logger.exception('STOP', 'Error stopping health monitor', e, stack);
    }
  }

  /// Emit heartbeat
  void _emitHeartbeat() {
    try {
      final now = DateTime.now();
      final uptime = _startTime != null
          ? now.difference(_startTime!).inSeconds
          : 0;

      _prefs.setString(
        AppConstants.kLastHealthCheck,
        now.toIso8601String(),
      );

      _prefs.setBool(AppConstants.kServiceRunning, true);

      _logger.debug('HEARTBEAT', 'Heartbeat emitted', {
        'uptime_sec': uptime,
      });
    } catch (e) {
      _logger.exception('HEARTBEAT', 'Failed to emit heartbeat', e);
    }
  }

  /// Get current uptime in seconds
  int getUptimeSeconds() {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }

  /// Check if service is healthy
  bool isHealthy() {
    return _isRunning;
  }

  /// Get health metrics
  Map<String, dynamic> getMetrics() {
    final totalScans = _prefs.getInt(AppConstants.kTotalScans) ?? 0;
    final failedScans = _prefs.getInt(AppConstants.kFailedScans) ?? 0;
    final tokenRefreshes = _prefs.getInt(AppConstants.kTokenRefreshes) ?? 0;
    final restartCount = _prefs.getInt(AppConstants.kRestartCount) ?? 0;

    return {
      'uptime_seconds': getUptimeSeconds(),
      'total_scans': totalScans,
      'failed_scans': failedScans,
      'token_refreshes': tokenRefreshes,
      'restart_count': restartCount,
      'success_rate': totalScans > 0
          ? ((totalScans - failedScans) / totalScans * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  /// Reset metrics
  Future<void> resetMetrics() async {
    await _prefs.setInt(AppConstants.kTotalScans, 0);
    await _prefs.setInt(AppConstants.kFailedScans, 0);
    await _prefs.setInt(AppConstants.kTokenRefreshes, 0);
    await _prefs.setInt(AppConstants.kRestartCount, 0);
    
    _logger.info('RESET', 'Health metrics reset');
  }
}
