import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_config.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// Manages alarm configuration state
class AlarmProvider with ChangeNotifier {
  static final _logger = Logger('ALARM_PROVIDER');

  final SharedPreferences _prefs;
  AlarmConfig _config;
  bool _isRinging = false;

  AlarmProvider(this._prefs)
      : _config = AlarmConfig.defaultConfig {
    _loadConfig();
  }

  // Getters
  AlarmConfig get config => _config;
  bool get isEnabled => _config.enabled;
  int get scanIntervalMinutes => _config.scanIntervalMinutes;
  List<String> get keywords => _config.keywords;
  bool get isRinging => _isRinging;

  /// Load configuration from storage
  void _loadConfig() {
    try {
      final enabled = _prefs.getBool(AppConstants.kAlarmEnabled) ?? false;
      final interval = _prefs.getInt(AppConstants.kScanInterval) ?? 5;
      final keywords = _prefs.getStringList(AppConstants.kKeywords) ?? [];
      final ringing = _prefs.getBool(AppConstants.kAlarmRinging) ?? false;

      _config = AlarmConfig(
        enabled: enabled,
        scanIntervalMinutes: interval,
        keywords: keywords,
      );
      _isRinging = ringing;

      _logger.info('LOAD', 'Config loaded', {
        'enabled': enabled,
        'interval': interval,
        'keywords': keywords.length,
      });
    } catch (e, stack) {
      _logger.exception('LOAD', 'Failed to load config', e, stack);
    }
  }

  /// Set alarm enabled state
  Future<void> setEnabled(bool enabled) async {
    try {
      await _prefs.setBool(AppConstants.kAlarmEnabled, enabled);
      _config = _config.copyWith(enabled: enabled);
      
      _logger.info('SET_ENABLED', 'Alarm enabled state changed', {
        'enabled': enabled,
      });
      
      notifyListeners();
    } catch (e, stack) {
      _logger.exception('SET_ENABLED', 'Failed to set enabled state', e, stack);
    }
  }

  /// Set scan interval
  Future<void> setScanInterval(int minutes) async {
    if (minutes < AppConstants.minScanInterval.inMinutes ||
        minutes > AppConstants.maxScanInterval.inMinutes) {
      _logger.warn('SET_INTERVAL', 'Invalid scan interval', {
        'minutes': minutes,
      });
      return;
    }

    try {
      await _prefs.setInt(AppConstants.kScanInterval, minutes);
      _config = _config.copyWith(scanIntervalMinutes: minutes);
      
      _logger.info('SET_INTERVAL', 'Scan interval changed', {
        'minutes': minutes,
      });
      
      notifyListeners();
    } catch (e, stack) {
      _logger.exception('SET_INTERVAL', 'Failed to set scan interval', e, stack);
    }
  }

  /// Set keywords
  Future<void> setKeywords(List<String> keywords) async {
    try {
      await _prefs.setStringList(AppConstants.kKeywords, keywords);
      _config = _config.copyWith(keywords: keywords);
      
      _logger.info('SET_KEYWORDS', 'Keywords updated', {
        'count': keywords.length,
      });
      
      notifyListeners();
    } catch (e, stack) {
      _logger.exception('SET_KEYWORDS', 'Failed to set keywords', e, stack);
    }
  }

  /// Add keyword
  Future<void> addKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;

    final newKeywords = [..._config.keywords, keyword.trim()];
    await setKeywords(newKeywords);
  }

  /// Remove keyword
  Future<void> removeKeyword(String keyword) async {
    final newKeywords = _config.keywords.where((k) => k != keyword).toList();
    await setKeywords(newKeywords);
  }

  /// Update ringing state
  void updateRingingState(bool ringing) {
    _isRinging = ringing;
    _logger.info('UPDATE_RINGING', 'Ringing state updated', {
      'ringing': ringing,
    });
    notifyListeners();
  }

  /// Refresh state from storage
  void refresh() {
    _loadConfig();
    notifyListeners();
  }

  /// Clear all dismissed emails
  Future<void> clearDismissedEmails() async {
    try {
      await _prefs.remove(AppConstants.kDismissedIds);
      _logger.info('CLEAR', 'Dismissed emails cleared');
    } catch (e, stack) {
      _logger.exception('CLEAR', 'Failed to clear dismissed emails', e, stack);
    }
  }
}
