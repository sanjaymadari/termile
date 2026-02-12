import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

/// Represents an SSH session with its associated terminal and connection details
class SSHSessionModel {
  final String id;
  final String name;
  final String host;
  final String username;
  final int port;
  final Terminal terminal;
  SSHClient? client;
  SSHSession? session;
  bool isConnected;
  bool isConnecting;
  DateTime? connectedAt;

  SSHSessionModel({
    required this.id,
    required this.name,
    required this.host,
    required this.username,
    required this.port,
    Terminal? terminal,
    this.client,
    this.session,
    this.isConnected = false,
    this.isConnecting = false,
    this.connectedAt,
  }) : terminal = terminal ?? Terminal();

  /// Create a unique ID for the session
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Get a display name for the tab
  String get displayName {
    if (name.isNotEmpty) return name;
    return '$username@$host';
  }

  /// Get connection status text
  String get statusText {
    if (isConnecting) return 'Connecting...';
    if (isConnected) return 'Connected';
    return 'Disconnected';
  }

  /// Get connection duration
  String get connectionDuration {
    if (connectedAt == null) return '';
    final duration = DateTime.now().difference(connectedAt!);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    session?.close();
    client?.close();
    isConnected = false;
    isConnecting = false;
    connectedAt = null;
  }
}
