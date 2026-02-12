import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ssh_session.dart';
import '../models/terminal_theme.dart';
import '../models/terminal_settings.dart';
import '../connection_profile.dart';
import '../services/sftp_service.dart';
import '../widgets/extra_keys_row.dart';
import '../widgets/session_tab_bar.dart';
import '../widgets/terminal_view.dart';
import '../widgets/terminal_settings_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/ssh_key_dropdown.dart';
import '../widgets/snippet_picker_sheet.dart';
import 'sftp_browser_screen.dart';
import 'local_terminal_screen.dart';
import '../services/local_terminal_service.dart';

/// Main terminal screen with multi-session support and Termux-like features
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with TickerProviderStateMixin {
  // Sessions management
  final List<SSHSessionModel> _sessions = [];
  int _activeSessionIndex = 0;

  // Connection form controllers
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _passwordController = TextEditingController();
  final _profileNameController = TextEditingController();

  // Settings and state
  TerminalSettings _settings = TerminalSettings();
  AppTerminalTheme _currentTheme = AppTerminalTheme.defaultDark;
  List<ConnectionProfile> _savedProfiles = [];
  List<Map<String, String>> _availableKeys = [];
  String? _privateKeyPath;
  String? _privateKeyContent;
  bool _usePasswordAuth = false;

  // Focus
  final _terminalFocusNode = FocusNode();

  // Current session getter
  SSHSessionModel? get _currentSession =>
      _sessions.isNotEmpty ? _sessions[_activeSessionIndex] : null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSavedProfiles();
    _loadAvailableKeys();
    _checkExistingKeys();
    // Create initial session
    _createNewSession();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _profileNameController.dispose();
    _terminalFocusNode.dispose();
    // Cleanup all sessions
    for (final session in _sessions) {
      session.disconnect();
    }
    super.dispose();
  }

  // ==================== Settings ====================

  Future<void> _loadSettings() async {
    final settings = await TerminalSettings.load();
    setState(() {
      _settings = settings;
      _currentTheme = AppTerminalTheme.getById(settings.themeId);
    });
  }

  Future<void> _saveSettings() async {
    await _settings.save();
  }

  void _openSettings() {
    TerminalSettingsDialog.show(
      context,
      settings: _settings,
      onSettingsChanged: (newSettings) {
        setState(() {
          _settings = newSettings;
          _currentTheme = AppTerminalTheme.getById(newSettings.themeId);
        });
        _saveSettings();
      },
    );
  }

  // ==================== Session Management ====================

  void _createNewSession() {
    final session = SSHSessionModel(
      id: SSHSessionModel.generateId(),
      name: 'New Session',
      host: '',
      username: '',
      port: 22,
    );
    setState(() {
      _sessions.add(session);
      _activeSessionIndex = _sessions.length - 1;
    });
  }

  void _selectSession(int index) {
    if (index >= 0 && index < _sessions.length) {
      setState(() {
        _activeSessionIndex = index;
      });
      // Load connection details if available
      final session = _sessions[index];
      _ipController.text = session.host;
      _usernameController.text = session.username;
      _portController.text = session.port.toString();
    }
  }

  Future<void> _closeSession(int index) async {
    if (_sessions.length == 1) {
      // Don't close the last session, just disconnect
      await _sessions[0].disconnect();
      setState(() {
        _sessions[0] = SSHSessionModel(
          id: SSHSessionModel.generateId(),
          name: 'New Session',
          host: '',
          username: '',
          port: 22,
        );
      });
      return;
    }

    await _sessions[index].disconnect();
    setState(() {
      _sessions.removeAt(index);
      if (_activeSessionIndex >= _sessions.length) {
        _activeSessionIndex = _sessions.length - 1;
      }
    });
  }

  // ==================== Connection ====================

  Future<void> _connect() async {
    final List<String> missingFields = [];

    if (_ipController.text.isEmpty) {
      missingFields.add('IP Address');
    }
    if (_usernameController.text.isEmpty) {
      missingFields.add('Username');
    }
    if (_portController.text.isEmpty) {
      missingFields.add('Port');
    } else {
      final port = int.tryParse(_portController.text);
      if (port == null || port < 1 || port > 65535) {
        missingFields.add('Valid Port (1-65535)');
      }
    }
    if (_usePasswordAuth) {
      if (_passwordController.text.isEmpty) {
        missingFields.add('Password');
      }
    } else {
      if (_privateKeyContent == null) {
        missingFields.add('SSH Key');
      }
    }

    if (missingFields.isNotEmpty) {
      _showError('Please fill in: ${missingFields.join(', ')}');
      return;
    }

    final session = _currentSession;
    if (session == null) return;

    // Update session details
    setState(() {
      _sessions[_activeSessionIndex] = SSHSessionModel(
        id: session.id,
        name: '${_usernameController.text}@${_ipController.text}',
        host: _ipController.text,
        username: _usernameController.text,
        port: int.tryParse(_portController.text) ?? 22,
        terminal: session.terminal,
        isConnecting: true,
      );
    });

    try {
      final port = int.tryParse(_portController.text) ?? 22;

      final socket = await SSHSocket.connect(
        _ipController.text,
        port,
        timeout: const Duration(seconds: 30),
      ).catchError((error) {
        throw Exception(
          'Network error: $error\nPlease check your connection and firewall settings.',
        );
      });

      SSHClient client;
      if (_usePasswordAuth) {
        client = SSHClient(socket, username: _usernameController.text);
      } else {
        client = SSHClient(
          socket,
          username: _usernameController.text,
          identities: [...SSHKeyPair.fromPem(_privateKeyContent!)],
        );
      }

      await client.authenticated.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Authentication timeout'),
      );

      final sshSession = await client.shell(
        pty: SSHPtyConfig(width: 80, height: session.terminal.viewHeight),
      );

      // Setup terminal I/O
      sshSession.stdout.listen(
        (data) => session.terminal.write(String.fromCharCodes(data)),
        onError: (error) => _showError('Output error: $error'),
      );

      sshSession.stderr.listen(
        (data) => session.terminal.write(String.fromCharCodes(data)),
        onError: (error) => _showError('Error output: $error'),
      );

      session.terminal.onOutput = (data) {
        sshSession.write(Uint8List.fromList(data.codeUnits));
      };

      // Update session state
      setState(() {
        final updatedSession = SSHSessionModel(
          id: session.id,
          name: '${_usernameController.text}@${_ipController.text}',
          host: _ipController.text,
          username: _usernameController.text,
          port: port,
          terminal: session.terminal,
          client: client,
          session: sshSession,
          isConnected: true,
          isConnecting: false,
          connectedAt: DateTime.now(),
        );
        _sessions[_activeSessionIndex] = updatedSession;
      });
    } catch (e) {
      setState(() {
        final updatedSession = SSHSessionModel(
          id: session.id,
          name: session.name,
          host: _ipController.text,
          username: _usernameController.text,
          port: int.tryParse(_portController.text) ?? 22,
          terminal: session.terminal,
          isConnecting: false,
        );
        _sessions[_activeSessionIndex] = updatedSession;
      });
      _showError('Connection error: $e');
    }
  }

  Future<void> _disconnect() async {
    final session = _currentSession;
    if (session == null) return;

    await session.disconnect();
    setState(() {
      final updatedSession = SSHSessionModel(
        id: session.id,
        name: 'Disconnected',
        host: session.host,
        username: session.username,
        port: session.port,
        terminal: session.terminal,
      );
      _sessions[_activeSessionIndex] = updatedSession;
    });
  }

  // ==================== Extra Keys Handlers ====================

  void _sendControlKey(int keyCode) {
    final session = _currentSession;
    if (session?.session == null) return;
    // Control keys are sent as special sequences
  }

  void _sendEscape() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([27])); // ESC
  }

  void _sendTab() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([9])); // TAB
  }

  void _sendCtrlC() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([3])); // Ctrl+C
  }

  void _sendArrowUp() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([27, 91, 65])); // ESC [ A
  }

  void _sendArrowDown() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([27, 91, 66])); // ESC [ B
  }

  void _sendArrowLeft() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([27, 91, 68])); // ESC [ D
  }

  void _sendArrowRight() {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList([27, 91, 67])); // ESC [ C
  }

  void _sendKey(String key) {
    final session = _currentSession;
    if (session?.session == null) return;
    session!.session!.write(Uint8List.fromList(key.codeUnits));
  }

  // ==================== SFTP Browser ====================

  void _openSnippetPicker(SSHSessionModel session) {
    SnippetPickerSheet.show(
      context,
      onSnippetSelected: (snippet) {
        session.terminal.write(snippet.command);
        if (snippet.autoExecute) {
          session.terminal.write('\r');
        }
      },
    );
  }

  Future<void> _openSftpBrowser(SSHSessionModel session) async {
    if (session.client == null) {
      _showError('Not connected to server');
      return;
    }

    try {
      _showLoadingDialog('Opening file browser...');

      final sftp = await session.client!.sftp();
      final sftpService = SftpService(sftp);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SftpBrowserScreen(
              sftp: sftpService,
              initialPath: '/home/${session.username}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showError('Failed to open file browser: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ==================== Profile Management ====================

  Future<void> _loadSavedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString('connection_profiles');
      if (profilesJson != null) {
        final List<dynamic> profiles = jsonDecode(profilesJson);
        setState(() {
          _savedProfiles = profiles
              .map((profile) => ConnectionProfile.fromJson(profile))
              .toList();
        });
      }
    } catch (e) {
      _showError('Error loading profiles: $e');
    }
  }

  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = jsonEncode(
        _savedProfiles.map((p) => p.toJson()).toList(),
      );
      await prefs.setString('connection_profiles', profilesJson);
    } catch (e) {
      _showError('Error saving profiles: $e');
    }
  }

  Future<void> _saveCurrentProfile() async {
    final List<String> missingFields = [];

    if (_ipController.text.isEmpty) {
      missingFields.add('IP Address');
    }
    if (_usernameController.text.isEmpty) {
      missingFields.add('Username');
    }
    if (_portController.text.isEmpty) {
      missingFields.add('Port');
    }
    if (_usePasswordAuth && _passwordController.text.isEmpty) {
      missingFields.add('Password');
    }
    if (!_usePasswordAuth && _privateKeyPath == null) {
      missingFields.add('SSH Key');
    }

    if (missingFields.isNotEmpty) {
      _showError('Please fill in: ${missingFields.join(', ')}');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Connection Profile'),
        content: TextField(
          controller: _profileNameController,
          decoration: const InputDecoration(
            labelText: 'Profile Name',
            hintText: 'e.g., Development Server',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_profileNameController.text.isEmpty) {
                _showError('Please enter a profile name');
                return;
              }

              final newProfile = ConnectionProfile(
                name: _profileNameController.text,
                host: _ipController.text,
                username: _usernameController.text,
                port: int.parse(_portController.text),
                keyPath: _usePasswordAuth ? '' : _privateKeyPath!,
                usePasswordAuth: _usePasswordAuth,
                password: _usePasswordAuth ? _passwordController.text : null,
              );

              setState(() {
                _savedProfiles.add(newProfile);
              });
              await _saveProfiles();
              _profileNameController.clear();
              if (context.mounted) Navigator.pop(context);
              _showSuccess('Profile saved successfully');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _loadProfile(ConnectionProfile profile) {
    setState(() {
      _ipController.text = profile.host;
      _usernameController.text = profile.username;
      _portController.text = profile.port.toString();
      _usePasswordAuth = profile.usePasswordAuth;
      if (profile.usePasswordAuth) {
        _passwordController.text = profile.password ?? '';
        _privateKeyPath = null;
        _privateKeyContent = null;
      } else {
        _privateKeyPath = profile.keyPath;
        _passwordController.clear();
        if (profile.keyPath.isNotEmpty) {
          File(profile.keyPath).readAsString().then((content) {
            _privateKeyContent = content;
          }).catchError((error) {
            _showError('Error loading key: $error');
          });
        }
      }
    });
  }

  Future<void> _deleteProfile(ConnectionProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _savedProfiles.removeWhere((p) => p.name == profile.name);
      });
      await _saveProfiles();
      _showSuccess('Profile deleted');
    }
  }

  // ==================== SSH Key Management ====================

  Future<void> _checkExistingKeys() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final keysDir = Directory('${directory.path}/ssh_keys');

      if (await keysDir.exists()) {
        final files = await keysDir.list().toList();
        final privateKeyFiles = files
            .where(
              (file) =>
                  file is File &&
                  !file.path.endsWith('.pub') &&
                  (file.path.contains('id_rsa') ||
                      file.path.contains('imported')),
            )
            .cast<File>()
            .toList();

        if (privateKeyFiles.isNotEmpty) {
          privateKeyFiles.sort((a, b) => b.path.compareTo(a.path));
          final privateKeyFile = privateKeyFiles.first;
          final publicKeyFile = File('${privateKeyFile.path}.pub');

          if (await publicKeyFile.exists()) {
            _privateKeyPath = privateKeyFile.path;
            _privateKeyContent = await privateKeyFile.readAsString();
            setState(() {});
          }
        }
      }
    } catch (e) {
      _showError('Error checking existing keys: $e');
    }
  }

  Future<void> _loadAvailableKeys() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final keysDir = Directory('${directory.path}/ssh_keys');

      if (await keysDir.exists()) {
        final files = await keysDir.list().toList();
        final privateKeyFiles = files
            .where(
              (file) =>
                  file is File &&
                  !file.path.endsWith('.pub') &&
                  (file.path.contains('id_rsa') ||
                      file.path.contains('imported')),
            )
            .cast<File>()
            .toList();

        final availableKeys = <Map<String, String>>[];

        for (final privateKeyFile in privateKeyFiles) {
          final publicKeyFile = File('${privateKeyFile.path}.pub');

          if (await publicKeyFile.exists()) {
            final fileName = privateKeyFile.path.split('/').last;
            final keyType =
                fileName.contains('imported') ? 'Imported' : 'Generated';
            final timestamp =
                fileName.contains('_') ? fileName.split('_').last : 'Unknown';

            availableKeys.add({
              'privatePath': privateKeyFile.path,
              'publicPath': publicKeyFile.path,
              'name': fileName,
              'type': keyType,
              'timestamp': timestamp,
            });
          }
        }

        availableKeys.sort(
          (a, b) => b['timestamp']!.compareTo(a['timestamp']!),
        );

        setState(() {
          _availableKeys = availableKeys;
        });
      }
    } catch (e) {
      _showError('Error loading available keys: $e');
    }
  }

  Future<void> _importExistingKeys() async {
    try {
      final privateResult = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select private key (id_rsa)',
      );
      if (privateResult == null) return;

      final privateKey = await File(
        privateResult.files.single.path!,
      ).readAsString();

      if (!privateKey.contains('BEGIN') ||
          !privateKey.contains('PRIVATE KEY')) {
        _showError('Invalid private key format');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final keysDir = Directory('${directory.path}/ssh_keys');
      if (!await keysDir.exists()) {
        await keysDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${keysDir.path}/imported_$timestamp';

      await File(filePath).writeAsString(privateKey);

      _privateKeyPath = filePath;
      _privateKeyContent = privateKey;

      setState(() {});
      await _loadAvailableKeys();

      _showSuccess('SSH key imported successfully!');
    } catch (e) {
      _showError('Error importing keys: $e');
    }
  }

  Future<void> _selectKey(Map<String, String> keyInfo) async {
    try {
      final privateKeyFile = File(keyInfo['privatePath']!);
      final publicKeyFile = File(keyInfo['publicPath']!);

      if (await privateKeyFile.exists() && await publicKeyFile.exists()) {
        _privateKeyPath = privateKeyFile.path;
        _privateKeyContent = await privateKeyFile.readAsString();

        setState(() {});
        _showSuccess('Selected key: ${keyInfo['name']}');
      } else {
        _showError('Key files not found');
      }
    } catch (e) {
      _showError('Error selecting key: $e');
    }
  }

  // ==================== UI Helpers ====================

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== Build Methods ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.background,
      appBar: CustomAppBar(
        title: 'Termile',
        isHomeScreen: true,
        actions: [
          // Font size controls
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () {
              setState(() {
                _settings.decreaseFontSize();
              });
              _saveSettings();
            },
            tooltip: 'Decrease font size',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () {
              setState(() {
                _settings.increaseFontSize();
              });
              _saveSettings();
            },
            tooltip: 'Increase font size',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Session tabs
          SessionTabBar(
            sessions: _sessions,
            activeIndex: _activeSessionIndex,
            onTabSelected: _selectSession,
            onTabClosed: _closeSession,
            onNewTab: _createNewSession,
          ),
          // Main content
          Expanded(
            child: _currentSession?.isConnected == true
                ? _buildTerminalView()
                : _buildConnectionForm(),
          ),
          // Extra keys row
          if (_settings.showExtraKeys && _currentSession?.isConnected == true)
            ExtraKeysRow(
              keys: _settings.extraKeys,
              onKeyPress: _sendKey,
              onControlKey: _sendControlKey,
              onEscape: _sendEscape,
              onTab: _sendTab,
              onArrowUp: _sendArrowUp,
              onArrowDown: _sendArrowDown,
              onArrowLeft: _sendArrowLeft,
              onArrowRight: _sendArrowRight,
              hapticFeedback: _settings.hapticFeedback,
            ),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    final session = _currentSession;
    if (session == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Connection info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade700, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.displayName,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.connectedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        session.connectionDuration,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // SFTP File Browser
              IconButton(
                icon: const Icon(Icons.folder, size: 20),
                onPressed: () => _openSftpBrowser(session),
                tooltip: 'File Browser',
                color: Colors.blue.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // Command Snippets
              IconButton(
                icon: const Icon(Icons.receipt_long, size: 20),
                onPressed: () => _openSnippetPicker(session),
                tooltip: 'Snippets',
                color: Colors.teal.shade300,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // Terminal actions
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                onPressed: () {
                  // Use ANSI escape sequence to clear terminal and reset cursor
                  // \x1b[2J - Clear screen
                  // \x1b[H  - Move cursor to home (top-left)
                  session.terminal.write('\x1b[2J\x1b[H');
                },
                tooltip: 'Clear terminal',
                color: Colors.grey.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop, size: 20),
                onPressed: _sendCtrlC,
                tooltip: 'Send Ctrl+C',
                color: Colors.orange.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                onPressed: _disconnect,
                tooltip: 'Disconnect',
                color: Colors.red.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Terminal
        Expanded(
          child: TerminalViewWidget(
            terminal: session.terminal,
            theme: _currentTheme,
            settings: _settings,
            focusNode: _terminalFocusNode,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionForm() {
    final session = _currentSession;
    final isConnecting = session?.isConnecting == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connection Details Card
        _buildCard(
          title: 'Connection Details',
          icon: Icons.settings_ethernet,
          color: Colors.green,
          child: Column(
            children: [
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.1.1',
                  prefixIcon: Icon(Icons.computer),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'ubuntu',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '22',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Authentication Card
        _buildCard(
          title: 'Authentication',
          icon: Icons.security,
          color: Colors.blue,
          child: Column(
            children: [
              // Auth method toggle
              Row(
                children: [
                  Expanded(
                    child: _buildAuthMethodButton(
                      label: 'SSH Key',
                      icon: Icons.vpn_key,
                      isSelected: !_usePasswordAuth,
                      onTap: () => setState(() => _usePasswordAuth = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAuthMethodButton(
                      label: 'Password',
                      icon: Icons.lock,
                      isSelected: _usePasswordAuth,
                      onTap: () => setState(() => _usePasswordAuth = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_usePasswordAuth)
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                )
              else
                SshKeyDropdown(
                  availableKeys: _availableKeys,
                  selectedKeyPath: _privateKeyPath,
                  onKeySelected: (keyInfo) => _selectKey(keyInfo),
                  onImportKey: _importExistingKeys,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isConnecting ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isConnecting
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Connecting...'),
                        ],
                      )
                    : const Text('Connect'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _saveCurrentProfile,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Icon(Icons.save),
            ),
          ],
        ),
        // Local Terminal Button (desktop/Android only)
        if (LocalTerminalService.isSupported) ...[
          const SizedBox(height: 16),
          _buildLocalTerminalCard(),
        ],
        const SizedBox(height: 24),
        // Saved Profiles
        if (_savedProfiles.isNotEmpty) ...[
          Text(
            'Saved Profiles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 12),
          ..._savedProfiles.map((profile) => _buildProfileTile(profile)),
        ],
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      color: Colors.grey.shade900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildAuthMethodButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade700.withValues(alpha: 0.3)
              : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade600,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade300 : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade300 : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(ConnectionProfile profile) {
    return Card(
      color: Colors.grey.shade800,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade700,
          child: Icon(
            profile.usePasswordAuth ? Icons.lock : Icons.vpn_key,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(profile.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '${profile.username}@${profile.host}:${profile.port}',
          style: TextStyle(color: Colors.grey.shade500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
              onPressed: () => _deleteProfile(profile),
            ),
          ],
        ),
        onTap: () => _loadProfile(profile),
      ),
    );
  }

  Widget _buildLocalTerminalCard() {
    return Card(
      color: Colors.grey.shade900,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocalTerminalScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.shade800.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.terminal,
                  color: Colors.green.shade400,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Terminal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Open a shell on ${LocalTerminalService.platformName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade600,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
