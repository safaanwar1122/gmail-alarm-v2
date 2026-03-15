import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/token_manager.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

/// Manages authentication state
class AuthProvider with ChangeNotifier {
  static final _logger = Logger('AUTH_PROVIDER');

  final GoogleSignIn _googleSignIn;
  final SharedPreferences _prefs;
  late final TokenManager _tokenManager;

  GoogleSignInAccount? _currentUser;
  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._googleSignIn, this._prefs) {
    _tokenManager = TokenManager(_googleSignIn, _prefs);
    _initialize();
  }

  // Getters
  bool get isSignedIn => _isSignedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  TokenManager get tokenManager => _tokenManager;

  /// Initialize auth provider
  Future<void> _initialize() async {
    _setLoading(true);
    
    try {
      _logger.info('INIT', 'Initializing auth provider');

      final initialized = await _tokenManager.initialize();
      
      if (initialized) {
        _currentUser = _googleSignIn.currentUser;
        _isSignedIn = _currentUser != null;
        
        _logger.info('INIT', 'Auth initialized', {
          'signed_in': _isSignedIn,
          'email': _currentUser?.email,
        });
      }
    } catch (e, stack) {
      _logger.exception('INIT', 'Auth initialization failed', e, stack);
      _error = 'Failed to initialize authentication';
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in user
  Future<bool> signIn() async {
    _setLoading(true);
    _clearError();

    try {
      _logger.info('SIGNIN', 'Starting sign-in');

      _currentUser = await _tokenManager.signIn();
      _isSignedIn = _currentUser != null;

      if (_isSignedIn) {
        _logger.info('SIGNIN', 'Sign-in successful', {
          'email': _currentUser!.email,
        });
        notifyListeners();
        return true;
      } else {
        _logger.warn('SIGNIN', 'Sign-in cancelled or failed');
        _error = 'Sign-in was cancelled';
        notifyListeners();
        return false;
      }
    } catch (e, stack) {
      _logger.exception('SIGNIN', 'Sign-in error', e, stack);
      _error = 'Failed to sign in: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      _logger.info('SIGNOUT', 'Signing out user');

      await _tokenManager.signOut();
      _currentUser = null;
      _isSignedIn = false;

      _logger.info('SIGNOUT', 'Sign-out successful');
      notifyListeners();
    } catch (e, stack) {
      _logger.exception('SIGNOUT', 'Sign-out error', e, stack);
      _error = 'Failed to sign out: ${e.toString()}';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Check if re-authentication is needed
  bool needsReauth() {
    return _tokenManager.needsReauth();
  }

  /// Reset after successful re-auth
  void resetReauth() {
    _tokenManager.resetRefreshAttempts();
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
