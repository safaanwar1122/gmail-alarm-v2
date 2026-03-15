/// Alarm configuration model
class AlarmConfig {
  final bool enabled;
  final int scanIntervalMinutes;
  final List<String> keywords;

  const AlarmConfig({
    required this.enabled,
    required this.scanIntervalMinutes,
    required this.keywords,
  });

  AlarmConfig copyWith({
    bool? enabled,
    int? scanIntervalMinutes,
    List<String>? keywords,
  }) {
    return AlarmConfig(
      enabled: enabled ?? this.enabled,
      scanIntervalMinutes: scanIntervalMinutes ?? this.scanIntervalMinutes,
      keywords: keywords ?? this.keywords,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'scanIntervalMinutes': scanIntervalMinutes,
      'keywords': keywords,
    };
  }

  factory AlarmConfig.fromJson(Map<String, dynamic> json) {
    return AlarmConfig(
      enabled: json['enabled'] as bool? ?? false,
      scanIntervalMinutes: json['scanIntervalMinutes'] as int? ?? 5,
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  static const AlarmConfig defaultConfig = AlarmConfig(
    enabled: false,
    scanIntervalMinutes: 5,
    keywords: [],
  );
}
