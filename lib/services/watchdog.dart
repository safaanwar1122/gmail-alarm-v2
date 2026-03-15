import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// Monitors service health and auto-restarts if dead
class Watchdog {
  static final _logger = Logger('WATCHDOG');
  final SharedPreferences _prefs;
  final Future<void> Function() _restartService;

  Timer? _checkTimer;
  bool _isMonitoring = false;
  int _consecutiveRestarts = 0;
  DateTime? _restartWindowStart;

  Watchdog(this._prefs, this._restartService);

  /// Start monitoring service health
  void start() {
    if (_isMonitoring) {
      _logger.warn('START', 'Watchdog already monitoring');
      return;
    }

    try {
      _logger.info('START', 'Starting watchdog');

      _isMonitoring = true;
      _checkTimer = Timer.periodic(
        AppConstants.serviceHealthCheckInterval,
        (_) => _checkServiceHealth(),
      );

      _logger.info('START', 'Watchdog started');
    } catch (e, stack) {
      _logger.exception('START', 'Failed to start watchdog', e, stack);
    }
  }

  /// Stop monitoring
  void stop() {
    if (!_isMonitoring) {
      return;
    }

    try {
      _logger.info('STOP', 'Stopping watchdog');

      _checkTimer?.cancel();
      _checkTimer = null;
      _isMonitoring = false;

      _logger.info('STOP', 'Watchdog stopped');
    } catch (e, stack) {
      _logger.exception('STOP', 'Error stopping watchdog', e, stack);
    }
  }

  /// Check service health
  Future<void> _checkServiceHealth() async {
    try {
      final lastHealthCheck = _prefs.getString(AppConstants.kLastHealthCheck);
      final serviceRunning = _prefs.getBool(AppConstants.kServiceRunning) ?? false;

      if (!serviceRunning) {
        _logger.warn('CHECK', 'Service not marked as running');
        return;
      }

      if (lastHealthCheck == null) {
        _logger.warn('CHECK', 'No health check timestamp found');
        return;
      }

      final lastCheck = DateTime.parse(lastHealthCheck);
      final age = DateTime.now().difference(lastCheck);

      _logger.debug('CHECK', 'Health check age', {
        'age_sec': age.inSeconds,
        'threshold_sec': AppConstants.serviceDeadThreshold.inSeconds,
      });

      // Check if service is dead
      if (age > AppConstants.serviceDeadThreshold) {
        _logger.error('CHECK', 'Service appears dead', {
          'age_min': age.inMinutes,
          'threshold_min': AppConstants.serviceDeadThreshold.inMinutes,
        });

        await _attemptRestart();
      }
    } catch (e, stack) {
      _logger.exception('CHECK', 'Error checking service health', e, stack);
    }
  }

  /// Attempt to restart service
  Future<void> _attemptRestart() async {
    // Reset restart window if expired
    if (_restartWindowStart != null) {
      final windowAge = DateTime.now().difference(_restartWindowStart!);
      if (windowAge > AppConstants.serviceRestartWindow) {
        _logger.info('RESTART', 'Restart window expired, resetting counter');
        _consecutiveRestarts = 0;
        _restartWindowStart = null;
      }
    }

    // Check if max restarts exceeded
    if (_consecutiveRestarts >= AppConstants.maxServiceRestarts) {
      _logger.error('RESTART', 'Max restart attempts exceeded', {
        'attempts': _consecutiveRestarts,
        'max': AppConstants.maxServiceRestarts,
      });
      
      // Mark service as not running
      await _prefs.setBool(AppConstants.kServiceRunning, false);
      return;
    }

    try {
      _consecutiveRestarts++;
      
      if (_restartWindowStart == null) {
        _restartWindowStart = DateTime.now();
      }

      // Calculate exponential backoff delay
      final delaySeconds = (AppConstants.retryBackoffMultiplier *
              _consecutiveRestarts)
          .toInt();

      _logger.warn('RESTART', 'Attempting service restart', {
        'attempt': _consecutiveRestarts,
        'max': AppConstants.maxServiceRestarts,
        'delay_sec': delaySeconds,
      });

      // Update restart count
      await _prefs.setInt(
        AppConstants.kRestartCount,
        (_prefs.getInt(AppConstants.kRestartCount) ?? 0) + 1,
      );

      // Wait before restart (exponential backoff)
      await Future.delayed(Duration(seconds: delaySeconds));

      // Attempt restart
      await _restartService();

      _logger.info('RESTART', 'Service restart initiated', {
        'attempt': _consecutiveRestarts,
      });

      // Wait a bit to see if service comes back
      await Future.delayed(const Duration(seconds: 10));

      // Check if restart was successful
      final lastHealthCheck = _prefs.getString(AppConstants.kLastHealthCheck);
      if (lastHealthCheck != null) {
        final lastCheck = DateTime.parse(lastHealthCheck);
        final age = DateTime.now().difference(lastCheck);

        if (age < const Duration(seconds: 30)) {
          _logger.info('RESTART', 'Service restart successful');
          _consecutiveRestarts = 0;
          _restartWindowStart = null;
          return;
        }
      }

      _logger.warn('RESTART', 'Service restart may have failed', {
        'attempt': _consecutiveRestarts,
      });
    } catch (e, stack) {
      _logger.exception('RESTART', 'Service restart failed', e, stack);
    }
  }

  /// Check if watchdog is monitoring
  bool isMonitoring() {
    return _isMonitoring;
  }

  /// Get restart count
  int getRestartCount() {
    return _consecutiveRestarts;
  }

  /// Reset restart counter (call after successful manual restart)
  void resetRestartCount() {
    _consecutiveRestarts = 0;
    _restartWindowStart = null;
    _logger.info('RESET', 'Restart counter reset');
  }
}
