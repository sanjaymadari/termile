import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/command_snippet.dart';

/// Service for managing command snippets stored in SharedPreferences
class SnippetService {
  static const String _storageKey = 'terminal_snippets';

  /// Load all snippets from storage
  static Future<List<CommandSnippet>> loadSnippets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data == null) {
        return _getDefaultSnippets();
      }

      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((j) => CommandSnippet.fromJson(j)).toList();
    } catch (e) {
      return _getDefaultSnippets();
    }
  }

  /// Save all snippets to storage
  static Future<void> saveSnippets(List<CommandSnippet> snippets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(snippets.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      // Handle error
    }
  }

  /// Add a new snippet
  static Future<void> addSnippet(CommandSnippet snippet) async {
    final snippets = await loadSnippets();
    snippets.add(snippet);
    await saveSnippets(snippets);
  }

  /// Delete a snippet
  static Future<void> deleteSnippet(String id) async {
    final snippets = await loadSnippets();
    snippets.removeWhere((s) => s.id == id);
    await saveSnippets(snippets);
  }

  /// Default snippets for new users
  static List<CommandSnippet> _getDefaultSnippets() {
    return [
      CommandSnippet(
        id: '1',
        name: 'List Files',
        command: 'ls -la',
        description: 'Detailed list of all files',
      ),
      CommandSnippet(
        id: '2',
        name: 'Disk Usage',
        command: 'df -h',
        description: 'Check free disk space',
      ),
      CommandSnippet(
        id: '3',
        name: 'System Info',
        command: 'uname -a',
        description: 'Kernel and OS info',
      ),
      CommandSnippet(
        id: '4',
        name: 'Running Procs',
        command: 'top -n 1',
        description: 'Show active processes',
      ),
    ];
  }
}
