import 'package:flutter/material.dart';

/// Terminal color scheme configuration
class AppTerminalTheme {
  final String id;
  final String name;
  final Color background;
  final Color foreground;
  final Color cursor;
  final Color selection;
  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;

  const AppTerminalTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.foreground,
    required this.cursor,
    required this.selection,
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
  });

  /// Default dark theme (similar to Termux default)
  static const defaultDark = AppTerminalTheme(
    id: 'default_dark',
    name: 'Default Dark',
    background: Color(0xFF1E1E1E),
    foreground: Color(0xFFD4D4D4),
    cursor: Color(0xFFAEAFAD),
    selection: Color(0xFF264F78),
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFFFFFFF),
  );

  /// Dracula theme
  static const dracula = AppTerminalTheme(
    id: 'dracula',
    name: 'Dracula',
    background: Color(0xFF282A36),
    foreground: Color(0xFFF8F8F2),
    cursor: Color(0xFFF8F8F2),
    selection: Color(0xFF44475A),
    black: Color(0xFF21222C),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFFBD93F9),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF6272A4),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
    brightWhite: Color(0xFFFFFFFF),
  );

  /// Solarized Dark theme
  static const solarizedDark = AppTerminalTheme(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    background: Color(0xFF002B36),
    foreground: Color(0xFF839496),
    cursor: Color(0xFF839496),
    selection: Color(0xFF073642),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
  );

  /// Monokai theme
  static const monokai = AppTerminalTheme(
    id: 'monokai',
    name: 'Monokai',
    background: Color(0xFF272822),
    foreground: Color(0xFFF8F8F2),
    cursor: Color(0xFFF8F8F0),
    selection: Color(0xFF49483E),
    black: Color(0xFF272822),
    red: Color(0xFFF92672),
    green: Color(0xFFA6E22E),
    yellow: Color(0xFFF4BF75),
    blue: Color(0xFF66D9EF),
    magenta: Color(0xFFAE81FF),
    cyan: Color(0xFFA1EFE4),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF75715E),
    brightRed: Color(0xFFF92672),
    brightGreen: Color(0xFFA6E22E),
    brightYellow: Color(0xFFF4BF75),
    brightBlue: Color(0xFF66D9EF),
    brightMagenta: Color(0xFFAE81FF),
    brightCyan: Color(0xFFA1EFE4),
    brightWhite: Color(0xFFF9F8F5),
  );

  /// Nord theme
  static const nord = AppTerminalTheme(
    id: 'nord',
    name: 'Nord',
    background: Color(0xFF2E3440),
    foreground: Color(0xFFD8DEE9),
    cursor: Color(0xFFD8DEE9),
    selection: Color(0xFF434C5E),
    black: Color(0xFF3B4252),
    red: Color(0xFFBF616A),
    green: Color(0xFFA3BE8C),
    yellow: Color(0xFFEBCB8B),
    blue: Color(0xFF81A1C1),
    magenta: Color(0xFFB48EAD),
    cyan: Color(0xFF88C0D0),
    white: Color(0xFFE5E9F0),
    brightBlack: Color(0xFF4C566A),
    brightRed: Color(0xFFBF616A),
    brightGreen: Color(0xFFA3BE8C),
    brightYellow: Color(0xFFEBCB8B),
    brightBlue: Color(0xFF81A1C1),
    brightMagenta: Color(0xFFB48EAD),
    brightCyan: Color(0xFF8FBCBB),
    brightWhite: Color(0xFFECEFF4),
  );

  /// One Dark theme
  static const oneDark = AppTerminalTheme(
    id: 'one_dark',
    name: 'One Dark',
    background: Color(0xFF282C34),
    foreground: Color(0xFFABB2BF),
    cursor: Color(0xFF528BFF),
    selection: Color(0xFF3E4451),
    black: Color(0xFF282C34),
    red: Color(0xFFE06C75),
    green: Color(0xFF98C379),
    yellow: Color(0xFFE5C07B),
    blue: Color(0xFF61AFEF),
    magenta: Color(0xFFC678DD),
    cyan: Color(0xFF56B6C2),
    white: Color(0xFFABB2BF),
    brightBlack: Color(0xFF5C6370),
    brightRed: Color(0xFFE06C75),
    brightGreen: Color(0xFF98C379),
    brightYellow: Color(0xFFE5C07B),
    brightBlue: Color(0xFF61AFEF),
    brightMagenta: Color(0xFFC678DD),
    brightCyan: Color(0xFF56B6C2),
    brightWhite: Color(0xFFFFFFFF),
  );

  /// Gruvbox Dark theme
  static const gruvboxDark = AppTerminalTheme(
    id: 'gruvbox_dark',
    name: 'Gruvbox Dark',
    background: Color(0xFF282828),
    foreground: Color(0xFFEBDBB2),
    cursor: Color(0xFFEBDBB2),
    selection: Color(0xFF504945),
    black: Color(0xFF282828),
    red: Color(0xFFCC241D),
    green: Color(0xFF98971A),
    yellow: Color(0xFFD79921),
    blue: Color(0xFF458588),
    magenta: Color(0xFFB16286),
    cyan: Color(0xFF689D6A),
    white: Color(0xFFA89984),
    brightBlack: Color(0xFF928374),
    brightRed: Color(0xFFFB4934),
    brightGreen: Color(0xFFB8BB26),
    brightYellow: Color(0xFFFABD2F),
    brightBlue: Color(0xFF83A598),
    brightMagenta: Color(0xFFD3869B),
    brightCyan: Color(0xFF8EC07C),
    brightWhite: Color(0xFFEBDBB2),
  );

  /// Tokyo Night theme
  static const tokyoNight = AppTerminalTheme(
    id: 'tokyo_night',
    name: 'Tokyo Night',
    background: Color(0xFF1A1B26),
    foreground: Color(0xFFA9B1D6),
    cursor: Color(0xFFC0CAF5),
    selection: Color(0xFF2E3C64),
    black: Color(0xFF15161E),
    red: Color(0xFFF7768E),
    green: Color(0xFF9ECE6A),
    yellow: Color(0xFFE0AF68),
    blue: Color(0xFF7AA2F7),
    magenta: Color(0xFFBB9AF7),
    cyan: Color(0xFF7DCFFF),
    white: Color(0xFFA9B1D6),
    brightBlack: Color(0xFF414868),
    brightRed: Color(0xFFF7768E),
    brightGreen: Color(0xFF9ECE6A),
    brightYellow: Color(0xFFE0AF68),
    brightBlue: Color(0xFF7AA2F7),
    brightMagenta: Color(0xFFBB9AF7),
    brightCyan: Color(0xFF7DCFFF),
    brightWhite: Color(0xFFC0CAF5),
  );

  /// Get all available themes
  static List<AppTerminalTheme> get allThemes => [
        defaultDark,
        dracula,
        solarizedDark,
        monokai,
        nord,
        oneDark,
        gruvboxDark,
        tokyoNight,
      ];

  /// Get theme by ID
  static AppTerminalTheme getById(String id) {
    return allThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => defaultDark,
    );
  }
}
