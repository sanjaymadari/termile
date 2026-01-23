import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Terminal settings configuration
class TerminalSettings {
  double fontSize;
  String themeId;
  bool showExtraKeys;
  bool hapticFeedback;
  bool bellEnabled;
  int scrollbackLines;
  String fontFamily;

  TerminalSettings({
    this.fontSize = 14.0,
    this.themeId = 'default_dark',
    this.showExtraKeys = true,
    this.hapticFeedback = true,
    this.bellEnabled = true,
    this.scrollbackLines = 10000,
    this.fontFamily = 'monospace',
  });

  /// Minimum font size
  static const double minFontSize = 8.0;

  /// Maximum font size
  static const double maxFontSize = 32.0;

  /// Default font size
  static const double defaultFontSize = 14.0;

  /// Copy with modifications
  TerminalSettings copyWith({
    double? fontSize,
    String? themeId,
    bool? showExtraKeys,
    bool? hapticFeedback,
    bool? bellEnabled,
    int? scrollbackLines,
    String? fontFamily,
  }) {
    return TerminalSettings(
      fontSize: fontSize ?? this.fontSize,
      themeId: themeId ?? this.themeId,
      showExtraKeys: showExtraKeys ?? this.showExtraKeys,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      bellEnabled: bellEnabled ?? this.bellEnabled,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'themeId': themeId,
      'showExtraKeys': showExtraKeys,
      'hapticFeedback': hapticFeedback,
      'bellEnabled': bellEnabled,
      'scrollbackLines': scrollbackLines,
      'fontFamily': fontFamily,
    };
  }

  /// Create from JSON
  factory TerminalSettings.fromJson(Map<String, dynamic> json) {
    return TerminalSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      themeId: json['themeId'] as String? ?? 'default_dark',
      showExtraKeys: json['showExtraKeys'] as bool? ?? true,
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      bellEnabled: json['bellEnabled'] as bool? ?? true,
      scrollbackLines: json['scrollbackLines'] as int? ?? 10000,
      fontFamily: json['fontFamily'] as String? ?? 'monospace',
    );
  }

  /// Load settings from SharedPreferences
  static Future<TerminalSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('terminal_settings');
      if (settingsJson != null) {
        return TerminalSettings.fromJson(jsonDecode(settingsJson));
      }
    } catch (e) {
      // Return default settings on error
    }
    return TerminalSettings();
  }

  /// Save settings to SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('terminal_settings', jsonEncode(toJson()));
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Increase font size
  void increaseFontSize() {
    if (fontSize < maxFontSize) {
      fontSize = (fontSize + 1).clamp(minFontSize, maxFontSize);
    }
  }

  /// Decrease font size
  void decreaseFontSize() {
    if (fontSize > minFontSize) {
      fontSize = (fontSize - 1).clamp(minFontSize, maxFontSize);
    }
  }

  /// Reset font size to default
  void resetFontSize() {
    fontSize = defaultFontSize;
  }
}
