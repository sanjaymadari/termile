// Model class for connection profiles
class ConnectionProfile {
  final String name;
  final String host;
  final String username;
  final int port;
  final String keyPath;
  final bool usePasswordAuth;
  final String? password; // Note: In production, this should be encrypted

  ConnectionProfile({
    required this.name,
    required this.host,
    required this.username,
    required this.port,
    required this.keyPath,
    this.usePasswordAuth = false,
    this.password,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'username': username,
        'port': port,
        'keyPath': keyPath,
        'usePasswordAuth': usePasswordAuth,
        'password': password,
      };

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) =>
      ConnectionProfile(
        name: json['name'],
        host: json['host'],
        username: json['username'],
        port: json['port'],
        keyPath: json['keyPath'],
        usePasswordAuth: json['usePasswordAuth'] ?? false,
        password: json['password'],
      );
}
