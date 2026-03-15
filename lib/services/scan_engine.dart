import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/email_match.dart';
import '../utils/logger.dart';
import 'token_manager.dart';

/// Gmail API wrapper with retry logic and keyword matching
class ScanEngine {
  static final _logger = Logger('SCAN');
  final TokenManager _tokenManager;
  final SharedPreferences _prefs;

  ScanEngine(this._tokenManager, this._prefs);

  /// Scan Gmail for matching emails
  Future<List<EmailMatch>> scan(List<String> keywords) async {
    if (keywords.isEmpty) {
      _logger.warn('SCAN', 'No keywords configured');
      return [];
    }

    try {
      _logger.info('SCAN', 'Starting email scan', {
        'keywords': keywords.length,
      });

      final matches = await _scanWithRetry(keywords);

      _logger.info('SCAN', 'Scan completed', {
        'matches': matches.length,
      });

      // Update scan statistics
      await _updateScanStats(success: true);
      await _prefs.setString(
        AppConstants.kLastScanTime,
        DateTime.now().toIso8601String(),
      );

      return matches;
    } catch (e, stack) {
      _logger.exception('SCAN', 'Scan failed', e, stack);
      await _updateScanStats(success: false);
      return [];
    }
  }

  /// Scan with exponential backoff retry
  Future<List<EmailMatch>> _scanWithRetry(
    List<String> keywords, {
    int attempt = 1,
  }) async {
    try {
      return await _performScan(keywords);
    } catch (e) {
      if (attempt >= AppConstants.maxRetryAttempts) {
        _logger.error('SCAN', 'Max retry attempts exceeded', {
          'attempts': attempt,
        });
        rethrow;
      }

      // Check if it's a rate limit error
      if (e.toString().contains('429') || e.toString().contains('rate')) {
        _logger.warn('SCAN', 'Rate limited, retrying', {
          'attempt': attempt,
        });
      } else {
        _logger.warn('SCAN', 'Scan failed, retrying', {
          'attempt': attempt,
          'error': e.toString(),
        });
      }

      // Exponential backoff
      final delayMs = AppConstants.initialRetryDelay.inMilliseconds *
          (AppConstants.retryBackoffMultiplier * attempt).toInt();
      
      await Future.delayed(Duration(milliseconds: delayMs));

      return await _scanWithRetry(keywords, attempt: attempt + 1);
    }
  }

  /// Perform actual Gmail scan
  Future<List<EmailMatch>> _performScan(List<String> keywords) async {
    // Get access token
    final token = await _tokenManager.getAccessToken();
    if (token == null) {
      throw Exception('No access token available');
    }

    // Create authenticated HTTP client
    final authClient = _AuthenticatedClient(token);
    final gmailApi = gmail.GmailApi(authClient);

    try {
      // Build query for unread emails
      const query = 'is:unread';

      // List messages
      final response = await gmailApi.users.messages.list(
        'me',
        q: query,
        maxResults: 50,
      );

      if (response.messages == null || response.messages!.isEmpty) {
        _logger.info('SCAN', 'No unread messages found');
        return [];
      }

      _logger.info('SCAN', 'Found unread messages', {
        'count': response.messages!.length,
      });

      // Filter and match emails
      final matches = <EmailMatch>[];
      final seenIds = _getSeenIds();
      final dismissedIds = _getDismissedIds();

      for (final message in response.messages!) {
        final messageId = message.id!;

        // Skip if already seen
        if (seenIds.contains(messageId)) {
          continue;
        }

        // Skip if dismissed
        if (dismissedIds.contains(messageId)) {
          continue;
        }

        // Fetch full message
        final fullMessage = await gmailApi.users.messages.get(
          'me',
          messageId,
          format: 'full',
        );

        // Extract email details
        final subject = _getHeader(fullMessage, 'Subject') ?? '';
        final from = _getHeader(fullMessage, 'From') ?? '';
        final snippet = fullMessage.snippet ?? '';
        final receivedAt = _parseInternalDate(fullMessage.internalDate);

        // Check for keyword match
        final matchedKeyword = _findMatchingKeyword(
          keywords,
          subject,
          from,
          snippet,
        );

        if (matchedKeyword != null) {
          _logger.info('SCAN', 'Email matched keyword', {
            'messageId': messageId,
            'keyword': matchedKeyword,
            'subject': subject,
          });

          matches.add(EmailMatch(
            id: messageId,
            subject: subject,
            from: from,
            snippet: snippet,
            receivedAt: receivedAt,
            matchedKeyword: matchedKeyword,
          ));
        }

        // Mark as seen
        _addSeenId(messageId);
      }

      // Clean up old seen IDs
      _cleanupSeenIds();

      return matches;
    } finally {
      authClient.close();
    }
  }

  /// Get header value from message
  String? _getHeader(gmail.Message message, String name) {
    if (message.payload?.headers == null) return null;

    for (final header in message.payload!.headers!) {
      if (header.name?.toLowerCase() == name.toLowerCase()) {
        return header.value;
      }
    }
    return null;
  }

  /// Parse internal date timestamp
  DateTime _parseInternalDate(String? internalDate) {
    if (internalDate == null) return DateTime.now();

    try {
      final timestamp = int.parse(internalDate);
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Find matching keyword in email content
  String? _findMatchingKeyword(
    List<String> keywords,
    String subject,
    String from,
    String snippet,
  ) {
    final content = '$subject $from $snippet'.toLowerCase();

    for (final keyword in keywords) {
      if (content.contains(keyword.toLowerCase())) {
        return keyword;
      }
    }

    return null;
  }

  /// Get seen email IDs from storage
  Set<String> _getSeenIds() {
    final stored = _prefs.getStringList(AppConstants.kSeenIds) ?? [];
    final now = DateTime.now();
    final validIds = <String>{};

    for (final entry in stored) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;

      final id = parts[0];
      final timestamp = DateTime.tryParse(parts[1]);

      if (timestamp != null) {
        final age = now.difference(timestamp);
        if (age < AppConstants.seenEmailRetention) {
          validIds.add(id);
        }
      }
    }

    return validIds;
  }

  /// Add email ID to seen list
  void _addSeenId(String id) {
    final seenIds = _getSeenIds();
    seenIds.add(id);

    // Store with timestamp
    final entries = seenIds.map((id) {
      return '$id|${DateTime.now().toIso8601String()}';
    }).toList();

    _prefs.setStringList(AppConstants.kSeenIds, entries);
  }

  /// Clean up old seen IDs
  void _cleanupSeenIds() {
    final seenIds = _getSeenIds();
    final entries = seenIds.map((id) {
      return '$id|${DateTime.now().toIso8601String()}';
    }).toList();

    _prefs.setStringList(AppConstants.kSeenIds, entries);
  }

  /// Get dismissed email IDs from storage
  Set<String> _getDismissedIds() {
    final stored = _prefs.getStringList(AppConstants.kDismissedIds) ?? [];
    return stored.toSet();
  }

  /// Update scan statistics
  Future<void> _updateScanStats({required bool success}) async {
    final totalScans = _prefs.getInt(AppConstants.kTotalScans) ?? 0;
    await _prefs.setInt(AppConstants.kTotalScans, totalScans + 1);

    if (!success) {
      final failedScans = _prefs.getInt(AppConstants.kFailedScans) ?? 0;
      await _prefs.setInt(AppConstants.kFailedScans, failedScans + 1);
    }
  }
}

/// Authenticated HTTP client for Gmail API
class _AuthenticatedClient extends http.BaseClient {
  final String _token;
  final http.Client _inner;

  _AuthenticatedClient(this._token) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
