import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../models/terminal_theme.dart';
import '../models/terminal_settings.dart';

/// Terminal view widget with copy/paste, theme, and font size support
class TerminalViewWidget extends StatefulWidget {
  final Terminal terminal;
  final AppTerminalTheme theme;
  final TerminalSettings settings;
  final FocusNode? focusNode;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;

  const TerminalViewWidget({
    super.key,
    required this.terminal,
    required this.theme,
    required this.settings,
    this.focusNode,
    this.onCopy,
    this.onPaste,
  });

  @override
  State<TerminalViewWidget> createState() => _TerminalViewWidgetState();
}

class _TerminalViewWidgetState extends State<TerminalViewWidget> {
  late TerminalController _terminalController;
  bool _showContextMenu = false;
  Offset _contextMenuPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
  }

  @override
  void dispose() {
    _terminalController.dispose();
    super.dispose();
  }

  TerminalStyle _buildTerminalStyle() {
    return TerminalStyle(
      fontSize: widget.settings.fontSize,
      fontFamily: widget.settings.fontFamily,
    );
  }

  TerminalTheme _buildTerminalTheme() {
    final t = widget.theme;
    return TerminalTheme(
      cursor: t.cursor,
      selection: t.selection,
      foreground: t.foreground,
      background: t.background,
      black: t.black,
      white: t.white,
      red: t.red,
      green: t.green,
      yellow: t.yellow,
      blue: t.blue,
      magenta: t.magenta,
      cyan: t.cyan,
      brightBlack: t.brightBlack,
      brightWhite: t.brightWhite,
      brightRed: t.brightRed,
      brightGreen: t.brightGreen,
      brightYellow: t.brightYellow,
      brightBlue: t.brightBlue,
      brightMagenta: t.brightMagenta,
      brightCyan: t.brightCyan,
      searchHitBackground: t.yellow,
      searchHitBackgroundCurrent: t.brightYellow,
      searchHitForeground: t.black,
    );
  }

  void _showCopyPasteMenu(TapDownDetails details) {
    setState(() {
      _showContextMenu = true;
      _contextMenuPosition = details.globalPosition;
    });
  }

  void _hideContextMenu() {
    setState(() {
      _showContextMenu = false;
    });
  }

  Future<void> _copyToClipboard() async {
    final selection = _terminalController.selection;
    if (selection != null) {
      final text = widget.terminal.buffer.getText(selection);
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
    _hideContextMenu();
    widget.onCopy?.call();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      widget.terminal.paste(data!.text!);
    }
    _hideContextMenu();
    widget.onPaste?.call();
  }

  void _clearSelection() {
    _terminalController.clearSelection();
    _hideContextMenu();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Terminal view
        GestureDetector(
          onLongPressStart: (details) => _showCopyPasteMenu(
            TapDownDetails(globalPosition: details.globalPosition),
          ),
          onTap: _hideContextMenu,
          child: Container(
            color: widget.theme.background,
            child: TerminalView(
              widget.terminal,
              controller: _terminalController,
              textStyle: _buildTerminalStyle(),
              theme: _buildTerminalTheme(),
              focusNode: widget.focusNode,
              autofocus: true,
              backgroundOpacity: 1.0,
              padding: const EdgeInsets.all(4),
            ),
          ),
        ),
        // Context menu overlay
        if (_showContextMenu)
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideContextMenu,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        // Context menu
        if (_showContextMenu)
          Positioned(
            left: _contextMenuPosition.dx - 60,
            top: _contextMenuPosition.dy - 50,
            child: _buildContextMenu(),
          ),
      ],
    );
  }

  Widget _buildContextMenu() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade800,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContextMenuItem(
              icon: Icons.copy,
              label: 'Copy',
              onTap: _copyToClipboard,
            ),
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade600,
            ),
            _buildContextMenuItem(
              icon: Icons.paste,
              label: 'Paste',
              onTap: _pasteFromClipboard,
            ),
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade600,
            ),
            _buildContextMenuItem(
              icon: Icons.clear,
              label: 'Clear',
              onTap: _clearSelection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
