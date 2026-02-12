import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

/// Service for managing local terminal sessions using pseudo-terminal (PTY)
class LocalTerminalService {
  Pty? _pty;
  Terminal? _terminal;
  bool _isRunning = false;

  /// Check if local terminal is supported on current platform
  static bool get isSupported {
    // flutter_pty supports macOS, Linux, Windows, and Android
    return Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isWindows ||
        Platform.isAndroid;
  }

  /// Get the default shell for the current platform
  static String get defaultShell {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment['SHELL'] ?? '/bin/bash';
    } else if (Platform.isWindows) {
      return 'cmd.exe';
    } else if (Platform.isAndroid) {
      return '/system/bin/sh';
    }
    return '/bin/sh';
  }

  /// Get the platform name for display
  static String get platformName {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  bool get isRunning => _isRunning;
  Terminal? get terminal => _terminal;

  /// Start a local terminal session
  Future<Terminal> startSession({
    int rows = 24,
    int columns = 80,
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Local terminal is not supported on ${Platform.operatingSystem}',
      );
    }

    // Create terminal instance
    _terminal = Terminal(
      maxLines: 10000,
    );

    // Build environment
    final env = <String, String>{
      ...Platform.environment,
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      ...?environment,
    };

    // Start PTY process
    _pty = Pty.start(
      defaultShell,
      columns: columns,
      rows: rows,
      workingDirectory: workingDirectory,
      environment: env,
    );

    _isRunning = true;

    // Listen to PTY output and write to terminal
    _pty!.output.cast<List<int>>().transform(const Utf8Decoder()).listen(
      (data) {
        _terminal?.write(data);
      },
      onError: (error) {
        if (kDebugMode) {
          print('PTY output error: $error');
        }
      },
      onDone: () {
        _isRunning = false;
      },
    );

    // Connect terminal output to PTY input
    _terminal!.onOutput = (data) {
      _pty?.write(const Utf8Encoder().convert(data));
    };

    // Handle terminal resize
    _terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      _pty?.resize(height, width);
    };

    return _terminal!;
  }

  /// Resize the terminal
  void resize(int rows, int columns) {
    _pty?.resize(rows, columns);
  }

  /// Write data to the terminal
  void write(String data) {
    _pty?.write(const Utf8Encoder().convert(data));
  }

  /// Kill the PTY process
  Future<void> kill() async {
    _pty?.kill();
    _isRunning = false;
  }

  /// Dispose of resources
  void dispose() {
    kill();
    _pty = null;
    _terminal = null;
  }
}
