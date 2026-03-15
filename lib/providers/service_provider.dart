import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/service_manager.dart';
import '../services/watchdog.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// Manages background service state
class ServiceProvider with ChangeNotifier {
  static final _logger = Logger('SERVICE_PROVIDER');

  final SharedPreferences _prefs;
  final ServiceManager _serviceManager;
  late final Watchdog _watchdog;

  bool _isRunning = false;
  bool _isStarting = false;
  String? _lastHealthCheck;
  Timer? _healthCheckTimer;

  ServiceProvider(this._prefs, this._serviceManager) {
    _watchdog = Watchdog(_prefs, _restartService);
    _initialize();
  }

  // Getters
  bool get isRunning => _isRunning;
  bool get isStarting => _isStarting;
  String? get lastHealthCheck => _lastHealthCheck;
  int get restartCount => _watchdog.getRestartCount();

  /// Initialize service provider
  Future<void> _initialize() async {
    try {
      _logger.info('INIT', 'Initializing service provider');

      // Check if service is running
      _isRunning = await _serviceManager.isServiceRunning();

      // Load last health check
      _lastHealthCheck = _prefs.getString(AppConstants.kLastHealthCheck);

      // Start watchdog
      _watchdog.start();

      // Start health check polling
      _startHealthCheckPolling();

      _logger.info('INIT', 'Service provider initialized', {
        'running': _isRunning,
      });

      notifyListeners();
    } catch (e, stack) {
      _logger.exception('INIT', 'Failed to initialize', e, stack);
    }
  }

  /// Start background service
  Future<bool> startService() async {
    if (_isRunning || _isStarting) {
      _logger.warn('START', 'Service already running or starting');
      return false;
    }

    _isStarting = true;
    notifyListeners();

    try {
      _logger.info('START', 'Starting background service');

      await _serviceManager.startService();

      // Wait a bit for service to start
      await Future.delayed(const Duration(seconds: 2));

      _isRunning = await _serviceManager.isServiceRunning();

      if (_isRunning) {
        _watchdog.resetRestartCount();
        _logger.info('START', 'Service started successfully');
      } else {
        _logger.error('START', 'Service failed to start');
      }

      return _isRunning;
    } catch (e, stack) {
      _logger.exception('START', 'Failed to start service', e, stack);
      return false;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  /// Stop background service
  Future<void> stopService() async {
    if (!_isRunning) {
      _logger.warn('STOP', 'Service not running');
      return;
    }

    try {
      _logger.info('STOP', 'Stopping background service');

      await _serviceManager.stopService();
      _isRunning = false;

      _logger.info('STOP', 'Service stopped successfully');
      notifyListeners();
    } catch (e, stack) {
      _logger.exception('STOP', 'Failed to stop service', e, stack);
    }
  }

  /// Restart background service
  Future<void> _restartService() async {
    _logger.info('RESTART', 'Restarting service');

    await stopService();
    await Future.delayed(const Duration(seconds: 2));
    await startService();
  }

  /// Start polling health check
  void _startHealthCheckPolling() {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateHealthCheck(),
    );
  }

  /// Update health check from storage
  void _updateHealthCheck() {
    try {
      final healthCheck = _prefs.getString(AppConstants.kLastHealthCheck);
      final serviceRunning = _prefs.getBool(AppConstants.kServiceRunning) ?? false;

      if (_lastHealthCheck != healthCheck || _isRunning != serviceRunning) {
        _lastHealthCheck = healthCheck;
        _isRunning = serviceRunning;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  /// Get time since last health check
  Duration? getHealthCheckAge() {
    if (_lastHealthCheck == null) return null;

    try {
      final lastCheck = DateTime.parse(_lastHealthCheck!);
      return DateTime.now().difference(lastCheck);
    } catch (e) {
      return null;
    }
  }

  /// Check if service is healthy
  bool isHealthy() {
    final age = getHealthCheckAge();
    if (age == null) return false;
    return age < AppConstants.serviceDeadThreshold;
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _watchdog.stop();
    super.dispose();
  }
}
