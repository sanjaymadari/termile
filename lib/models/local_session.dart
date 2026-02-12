import 'package:xterm/xterm.dart';

import '../services/local_terminal_service.dart';

/// Represents a local terminal session
class LocalSessionModel {
  final String id;
  final String name;
  final Terminal terminal;
  final LocalTerminalService service;
  bool isRunning;
  DateTime? startedAt;

  LocalSessionModel({
    required this.id,
    required this.name,
    required this.terminal,
    required this.service,
    this.isRunning = false,
    this.startedAt,
  });

  /// Create a unique ID for the session
  static String generateId() {
    return 'local_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get a display name for the tab
  String get displayName {
    if (name.isNotEmpty) return name;
    return 'Local Terminal';
  }

  /// Get session status text
  String get statusText {
    if (isRunning) return 'Running';
    return 'Stopped';
  }

  /// Get session duration
  String get sessionDuration {
    if (startedAt == null) return '';
    final duration = DateTime.now().difference(startedAt!);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }

  /// Stop and cleanup
  Future<void> stop() async {
    await service.kill();
    isRunning = false;
    startedAt = null;
  }

  /// Dispose of resources
  void dispose() {
    service.dispose();
  }
}
