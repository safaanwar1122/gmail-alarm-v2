import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// Manages Google OAuth tokens with proactive refresh
/// Refreshes at 45 min (before 60 min expiry)
class TokenManager {
  static final _logger = Logger('TOKEN');
  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;

  GoogleSignInAccount? _currentUser;
  DateTime? _tokenTimestamp;
  int _refreshAttempts = 0;

  TokenManager(this._googleSignIn, this._prefs) {
    _loadTokenTimestamp();
  }

  /// Initialize and check if user is already signed in
  Future<bool> initialize() async {
    try {
      _logger.info('INIT', 'Initializing token manager');
      
      // Try silent sign-in
      _currentUser = await _googleSignIn.signInSilently();
      
      if (_currentUser != null) {
        _logger.info('INIT', 'User already signed in', {
          'email': _currentUser!.email,
        });
        return true;
      }
      
      _logger.info('INIT', 'No user signed in');
      return false;
    } catch (e, stack) {
      _logger.exception('INIT', 'Failed to initialize', e, stack);
      return false;
    }
  }

  /// Sign in user
  Future<GoogleSignInAccount?> signIn() async {
    try {
      _logger.info('SIGNIN', 'Starting Google Sign-In');
      
      _currentUser = await _googleSignIn.signIn();
      
      if (_currentUser != null) {
        _tokenTimestamp = DateTime.now();
        await _saveTokenTimestamp();
        _refreshAttempts = 0;
        
        _logger.info('SIGNIN', 'Sign-in successful', {
          'email': _currentUser!.email,
        });
      } else {
        _logger.warn('SIGNIN', 'Sign-in cancelled by user');
      }
      
      return _currentUser;
    } catch (e, stack) {
      _logger.exception('SIGNIN', 'Sign-in failed', e, stack);
      return null;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      _logger.info('SIGNOUT', 'Signing out user');
      
      await _googleSignIn.signOut();
      _currentUser = null;
      _tokenTimestamp = null;
      _refreshAttempts = 0;
      
      await _prefs.remove(AppConstants.kTokenTimestamp);
      
      _logger.info('SIGNOUT', 'Sign-out successful');
    } catch (e, stack) {
      _logger.exception('SIGNOUT', 'Sign-out failed', e, stack);
    }
  }

  /// Get current access token
  Future<String?> getAccessToken() async {
    if (_currentUser == null) {
      _logger.warn('GET_TOKEN', 'No user signed in');
      return null;
    }

    try {
      // Check if token needs refresh
      if (_needsRefresh()) {
        _logger.info('GET_TOKEN', 'Token needs refresh', {
          'age': _getTokenAge().inMinutes,
          'threshold': AppConstants.tokenRefreshThreshold.inMinutes,
        });
        
        final refreshed = await _refreshToken();
        if (!refreshed) {
          _logger.warn('GET_TOKEN', 'Token refresh failed, using existing token');
        }
      }

      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (e, stack) {
      _logger.exception('GET_TOKEN', 'Failed to get access token', e, stack);
      return null;
    }
  }

  /// Check if current user is signed in
  bool isSignedIn() {
    return _currentUser != null;
  }

  /// Get current user email
  String? getUserEmail() {
    return _currentUser?.email;
  }

  /// Check if token needs refresh (proactive at 45 min)
  bool _needsRefresh() {
    if (_tokenTimestamp == null) return false;

    final testMode = _prefs.getBool(AppConstants.kTestMode) ?? false;
    final threshold = testMode
        ? AppConstants.testModeTokenExpiry
        : AppConstants.tokenRefreshThreshold;

    final age = _getTokenAge();
    return age >= threshold;
  }

  /// Get token age
  Duration _getTokenAge() {
    if (_tokenTimestamp == null) return Duration.zero;
    return DateTime.now().difference(_tokenTimestamp!);
  }

  /// Refresh access token with retry logic
  Future<bool> _refreshToken() async {
    if (_currentUser == null) {
      _logger.warn('REFRESH', 'No user to refresh token for');
      return false;
    }

    _refreshAttempts++;
    final age = _getTokenAge();

    try {
      _logger.info('REFRESH', 'Attempting token refresh', {
        'attempt': _refreshAttempts,
        'max_attempts': AppConstants.maxTokenRefreshRetries,
        'age_min': age.inMinutes,
      });

      // Force token refresh
      await _currentUser!.clearAuthCache();
      final auth = await _currentUser!.authentication;

      if (auth.accessToken != null) {
        _tokenTimestamp = DateTime.now();
        await _saveTokenTimestamp();
        _refreshAttempts = 0;

        await _prefs.setInt(
          AppConstants.kTokenRefreshes,
          (_prefs.getInt(AppConstants.kTokenRefreshes) ?? 0) + 1,
        );

        _logger.info('REFRESH', 'Token refreshed successfully', {
          'age_min': age.inMinutes,
          'attempt': _refreshAttempts,
        });
        return true;
      }

      _logger.warn('REFRESH', 'Token refresh returned null');
      return false;
    } catch (e, stack) {
      _logger.exception('REFRESH', 'Token refresh failed', e, stack);

      // Check if max retries exceeded
      if (_refreshAttempts >= AppConstants.maxTokenRefreshRetries) {
        _logger.error('REFRESH', 'Max token refresh attempts exceeded', {
          'attempts': _refreshAttempts,
          'max': AppConstants.maxTokenRefreshRetries,
        });
        // Don't reset attempts - let user know re-auth is needed
        return false;
      }

      // Exponential backoff for retry
      await _delayForRetry(_refreshAttempts);
      return false;
    }
  }

  /// Calculate exponential backoff delay
  Future<void> _delayForRetry(int attempt) async {
    final delayMs = AppConstants.initialRetryDelay.inMilliseconds *
        (AppConstants.retryBackoffMultiplier * attempt).toInt();
    
    _logger.info('REFRESH', 'Delaying before retry', {
      'delay_ms': delayMs,
      'attempt': attempt,
    });
    
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Load token timestamp from storage
  void _loadTokenTimestamp() {
    final timestamp = _prefs.getString(AppConstants.kTokenTimestamp);
    if (timestamp != null) {
      try {
        _tokenTimestamp = DateTime.parse(timestamp);
        _logger.info('LOAD', 'Token timestamp loaded', {
          'timestamp': timestamp,
          'age_min': _getTokenAge().inMinutes,
        });
      } catch (e) {
        _logger.warn('LOAD', 'Invalid token timestamp in storage');
        _tokenTimestamp = null;
      }
    }
  }

  /// Save token timestamp to storage
  Future<void> _saveTokenTimestamp() async {
    if (_tokenTimestamp != null) {
      await _prefs.setString(
        AppConstants.kTokenTimestamp,
        _tokenTimestamp!.toIso8601String(),
      );
    }
  }

  /// Check if re-authentication is needed
  bool needsReauth() {
    return _refreshAttempts >= AppConstants.maxTokenRefreshRetries;
  }

  /// Reset refresh attempts (after successful re-auth)
  void resetRefreshAttempts() {
    _refreshAttempts = 0;
    _logger.info('RESET', 'Refresh attempts reset');
  }
}
