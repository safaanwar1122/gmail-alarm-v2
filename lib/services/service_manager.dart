import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/constants.dart';
import '../utils/logger.dart';
import 'token_manager.dart';
import 'scan_engine.dart';
import 'alarm_manager.dart';
import 'health_monitor.dart';

/// Manages background service lifecycle
class ServiceManager {
  static final _logger = Logger('SERVICE');
  static ServiceManager? _instance;

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isRunning = false;

  ServiceManager._();

  static ServiceManager get instance {
    _instance ??= ServiceManager._();
    return _instance!;
  }

  /// Initialize background service
  Future<bool> initialize() async {
    try {
      _logger.info('INIT', 'Initializing background service');

      await _service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          autoStart: false,
          onStart: _onStart,
          isForegroundMode: true,
          autoStartOnBoot: true,
          foregroundServiceNotificationId: 888,
          initialNotificationTitle: 'Gmail Alarm',
          initialNotificationContent: 'Monitoring your Gmail inbox',
          foregroundServiceNotificationContent: 'Service is running',
        ),
      );

      _logger.info('INIT', 'Background service initialized');
      return true;
    } catch (e, stack) {
      _logger.exception('INIT', 'Failed to initialize service', e, stack);
      return false;
    }
  }

  /// Start background service
  Future<void> startService() async {
    if (_isRunning) {
      _logger.warn('START', 'Service already running');
      return;
    }

    try {
      _logger.info('START', 'Starting background service');

      final started = await _service.startService();
      
      if (started) {
        _isRunning = true;
        _logger.info('START', 'Background service started');
      } else {
        _logger.error('START', 'Failed to start background service');
      }
    } catch (e, stack) {
      _logger.exception('START', 'Error starting service', e, stack);
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

      _service.invoke('stop');
      _isRunning = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.kServiceRunning, false);

      _logger.info('STOP', 'Background service stopped');
    } catch (e, stack) {
      _logger.exception('STOP', 'Error stopping service', e, stack);
    }
  }

  /// Check if service is running
  Future<bool> isServiceRunning() async {
    final running = await _service.isRunning();
    _isRunning = running;
    return running;
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final logger = Logger('SERVICE_BG');
    logger.info('START', 'Background service started');

    try {
      // Initialize dependencies
      final prefs = await SharedPreferences.getInstance();
      final googleSignIn = GoogleSignIn(scopes: AppConstants.googleScopes);
      final notifications = FlutterLocalNotificationsPlugin();

      final tokenManager = TokenManager(googleSignIn, prefs);
      final scanEngine = ScanEngine(tokenManager, prefs);
      final alarmManager = AlarmManager(prefs, notifications);
      final healthMonitor = HealthMonitor(prefs);

      // Initialize services
      await tokenManager.initialize();
      await alarmManager.initialize();

      // Start health monitor
      healthMonitor.start();

      Timer? scanTimer;

      // Listen for stop command
      service.on('stop').listen((event) {
        logger.info('STOP', 'Stop command received');
        scanTimer?.cancel();
        healthMonitor.stop();
        service.stopSelf();
      });

      // Main scan loop
      void scheduleScan() {
        final enabled = prefs.getBool(AppConstants.kAlarmEnabled) ?? false;
        final intervalMin = prefs.getInt(AppConstants.kScanInterval) ?? 5;
        final keywords = prefs.getStringList(AppConstants.kKeywords) ?? [];

        if (!enabled) {
          logger.info('SCAN', 'Alarm disabled, skipping scan');
          scanTimer = Timer(
            Duration(minutes: intervalMin),
            scheduleScan,
          );
          return;
        }

        if (keywords.isEmpty) {
          logger.warn('SCAN', 'No keywords configured');
          scanTimer = Timer(
            Duration(minutes: intervalMin),
            scheduleScan,
          );
          return;
        }

        // Perform scan
        _performScan(
          scanEngine,
          alarmManager,
          prefs,
          keywords,
        ).then((_) {
          // Schedule next scan
          scanTimer = Timer(
            Duration(minutes: intervalMin),
            scheduleScan,
          );
        });
      }

      // Start scanning
      scheduleScan();

      logger.info('START', 'Background service initialized and running');
    } catch (e, stack) {
      logger.exception('START', 'Failed to start background service', e, stack);
      service.stopSelf();
    }
  }

  /// Perform email scan
  static Future<void> _performScan(
    ScanEngine scanEngine,
    AlarmManager alarmManager,
    SharedPreferences prefs,
    List<String> keywords,
  ) async {
    final logger = Logger('SERVICE_BG');

    try {
      logger.info('SCAN', 'Starting scan', {'keywords': keywords.length});

      final matches = await scanEngine.scan(keywords);

      if (matches.isNotEmpty) {
        logger.info('SCAN', 'Found matches', {'count': matches.length});

        // Trigger alarm if not already ringing
        if (!alarmManager.isRinging()) {
          await alarmManager.triggerAlarm(matches);
        } else {
          logger.info('SCAN', 'Alarm already ringing, skipping trigger');
        }
      } else {
        logger.info('SCAN', 'No matches found');
      }
    } catch (e, stack) {
      logger.exception('SCAN', 'Scan failed', e, stack);
    }
  }
}
