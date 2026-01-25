import 'dart:io';

import 'package:flutter/material.dart';

import '../models/local_session.dart';
import '../models/terminal_theme.dart';
import '../models/terminal_settings.dart';
import '../services/local_terminal_service.dart';
import '../widgets/terminal_view.dart';
import '../widgets/extra_keys_row.dart';
import '../widgets/terminal_settings_dialog.dart';

/// Screen for local terminal sessions (no SSH required)
class LocalTerminalScreen extends StatefulWidget {
  const LocalTerminalScreen({super.key});

  @override
  State<LocalTerminalScreen> createState() => _LocalTerminalScreenState();
}

class _LocalTerminalScreenState extends State<LocalTerminalScreen> {
  LocalSessionModel? _session;
  TerminalSettings _settings = TerminalSettings();
  AppTerminalTheme _currentTheme = AppTerminalTheme.defaultDark;
  bool _isLoading = true;
  String? _errorMessage;
  final _terminalFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startLocalTerminal();
  }

  @override
  void dispose() {
    _session?.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

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

  Future<void> _startLocalTerminal() async {
    if (!LocalTerminalService.isSupported) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Local terminal is not supported on ${Platform.operatingSystem}';
      });
      return;
    }

    try {
      final service = LocalTerminalService();
      final terminal = await service.startSession(
        rows: 24,
        columns: 80,
        workingDirectory: Platform.environment['HOME'] ?? '/',
      );

      setState(() {
        _session = LocalSessionModel(
          id: LocalSessionModel.generateId(),
          name: 'Local @ ${LocalTerminalService.platformName}',
          terminal: terminal,
          service: service,
          isRunning: true,
          startedAt: DateTime.now(),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to start local terminal: $e';
      });
    }
  }

  Future<void> _restartTerminal() async {
    _session?.dispose();
    setState(() {
      _session = null;
      _isLoading = true;
      _errorMessage = null;
    });
    await _startLocalTerminal();
  }

  void _sendControlKey(int keyCode) {
    // Control keys are ASCII 1-26 for Ctrl+A through Ctrl+Z
    _session?.service.write(String.fromCharCode(keyCode));
  }

  void _sendEscape() {
    _session?.service.write('\x1b');
  }

  void _sendTab() {
    _session?.service.write('\t');
  }

  void _sendArrowUp() {
    _session?.service.write('\x1b[A');
  }

  void _sendArrowDown() {
    _session?.service.write('\x1b[B');
  }

  void _sendArrowLeft() {
    _session?.service.write('\x1b[D');
  }

  void _sendArrowRight() {
    _session?.service.write('\x1b[C');
  }

  void _sendKey(String key) {
    _session?.service.write(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.terminal,
              color: Colors.green.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _session?.displayName ?? 'Local Terminal',
              style: const TextStyle(fontSize: 16),
            ),
            if (_session?.isRunning == true) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartTerminal,
            tooltip: 'Restart Terminal',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Starting local terminal...',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Local Terminal Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startLocalTerminal,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return const Center(child: Text('No session available'));
    }

    return Column(
      children: [
        // Terminal view
        Expanded(
          child: TerminalViewWidget(
            terminal: session.terminal,
            theme: _currentTheme,
            settings: _settings,
            focusNode: _terminalFocusNode,
          ),
        ),
        // Extra keys row
        if (_settings.showExtraKeys)
          ExtraKeysRow(
            keys: _settings.extraKeys,
            onKeyPress: _sendKey,
            onControlKey: _sendControlKey,
            onTab: _sendTab,
            onEscape: _sendEscape,
            onArrowUp: _sendArrowUp,
            onArrowDown: _sendArrowDown,
            onArrowLeft: _sendArrowLeft,
            onArrowRight: _sendArrowRight,
            hapticFeedback: _settings.hapticFeedback,
          ),
      ],
    );
  }
}
