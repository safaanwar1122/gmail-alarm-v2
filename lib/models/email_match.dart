/// Represents a matched email that triggered the alarm
class EmailMatch {
  final String id;
  final String subject;
  final String from;
  final String snippet;
  final DateTime receivedAt;
  final String matchedKeyword;

  const EmailMatch({
    required this.id,
    required this.subject,
    required this.from,
    required this.snippet,
    required this.receivedAt,
    required this.matchedKeyword,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'from': from,
      'snippet': snippet,
      'receivedAt': receivedAt.toIso8601String(),
      'matchedKeyword': matchedKeyword,
    };
  }

  factory EmailMatch.fromJson(Map<String, dynamic> json) {
    return EmailMatch(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '',
      from: json['from'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      matchedKeyword: json['matchedKeyword'] as String? ?? '',
    );
  }
}
