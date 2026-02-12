/// Represents a reusable terminal command snippet
class CommandSnippet {
  final String id;
  final String name;
  final String command;
  final String? description;
  final bool autoExecute;

  CommandSnippet({
    required this.id,
    required this.name,
    required this.command,
    this.description,
    this.autoExecute = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'command': command,
      'description': description,
      'autoExecute': autoExecute,
    };
  }

  factory CommandSnippet.fromJson(Map<String, dynamic> json) {
    return CommandSnippet(
      id: json['id'] as String,
      name: json['name'] as String,
      command: json['command'] as String,
      description: json['description'] as String?,
      autoExecute: json['autoExecute'] as bool? ?? true,
    );
  }

  /// Create a copy with modifications
  CommandSnippet copyWith({
    String? name,
    String? command,
    String? description,
    bool? autoExecute,
  }) {
    return CommandSnippet(
      id: id,
      name: name ?? this.name,
      command: command ?? this.command,
      description: description ?? this.description,
      autoExecute: autoExecute ?? this.autoExecute,
    );
  }
}
