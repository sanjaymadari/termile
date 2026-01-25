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
  final _searchController = TextEditingController();
  bool _showSearchBar = false;
  bool _showContextMenu = false;
  Offset _contextMenuPosition = Offset.zero;
  late ScrollController _scrollController;
  int _currentMatchIndex = -1;
  final List<TerminalHighlight> _searchHighlights = [];

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _clearHighlights();
    super.dispose();
  }

  void _clearHighlights() {
    for (final h in _searchHighlights) {
      h.dispose();
    }
    _searchHighlights.clear();
    _currentMatchIndex = -1;
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _clearHighlights();
      }
    });
  }

  void _jumpToMatch(int index) {
    if (_searchHighlights.isEmpty) return;

    setState(() {
      _currentMatchIndex = index % _searchHighlights.length;
    });

    final highlight = _searchHighlights[_currentMatchIndex];
    final lineIndex = highlight.p1.y;

    // Calculate scroll position.
    // Each line has height widget.settings.fontSize * lineSpacing.
    // TerminalView uses its own internal calculation for line height.
    // We can roughly estimate it or use the cellSize if we could access it.
    // In RenderTerminal, lineHeight = _painter.cellSize.height.

    final charHeight = _getEstimatedLineHeight();
    final targetScroll = lineIndex * charHeight;

    _scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  double _getEstimatedLineHeight() {
    // This is a heuristic. xterm.dart usually adds a bit of padding.
    return widget.settings.fontSize * 1.2;
  }

  void _performSearch(String pattern) {
    _clearHighlights();

    if (pattern.isEmpty) {
      setState(() {});
      return;
    }

    final searchHits = <TerminalHighlight>[];
    final lines = widget.terminal.buffer.lines;
    final regex = RegExp(pattern, caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.getText();
      final matches = regex.allMatches(text);

      for (final match in matches) {
        final startX = _mapCharIndexToCellIndex(line, match.start);
        final endX = _mapCharIndexToCellIndex(line, match.end);

        final h = _terminalController.highlight(
          p1: widget.terminal.buffer.createAnchor(startX, i),
          p2: widget.terminal.buffer.createAnchor(endX, i),
          color: Colors.orange.withValues(alpha: 0.5),
        );
        searchHits.add(h);
      }
    }

    setState(() {
      _searchHighlights.addAll(searchHits);
      if (_searchHighlights.isNotEmpty) {
        _currentMatchIndex = 0;
      }
    });

    if (_searchHighlights.isNotEmpty) {
      _jumpToMatch(0);
    }
  }

  int _mapCharIndexToCellIndex(BufferLine line, int charIndex) {
    var currentCharIndex = 0;
    for (var i = 0; i < line.length; i++) {
      if (currentCharIndex >= charIndex) return i;
      final codePoint = line.getCodePoint(i);
      if (codePoint == 0) continue; // Skip wide char fillers
      currentCharIndex++;
      final width = line.getWidth(i);
      if (width == 2) i++; // Skip the next cell for wide chars
    }
    return line.length;
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
      searchHitBackground: Colors.yellow.withValues(alpha: 0.5),
      searchHitBackgroundCurrent: Colors.orange.withValues(alpha: 0.7),
      searchHitForeground: Colors.black,
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
          onTap: () {
            _hideContextMenu();
            if (_showSearchBar) {
              FocusScope.of(context).unfocus();
            }
          },
          child: Container(
            color: widget.theme.background,
            child: Column(
              children: [
                if (_showSearchBar) _buildSearchBar(),
                Expanded(
                  child: TerminalView(
                    widget.terminal,
                    controller: _terminalController,
                    scrollController: _scrollController,
                    textStyle: _buildTerminalStyle(),
                    theme: _buildTerminalTheme(),
                    focusNode: widget.focusNode,
                    autofocus: true,
                    backgroundOpacity: 1.0,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Search toggle button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            onPressed: _toggleSearchBar,
            backgroundColor: Colors.blue.withValues(alpha: 0.3),
            child: Icon(
              _showSearchBar ? Icons.close : Icons.search,
              color: Colors.white,
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Find in terminal...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                suffixText: _searchHighlights.isNotEmpty
                    ? '${_searchHighlights.length} matches'
                    : null,
                suffixStyle:
                    TextStyle(color: Colors.blue.shade300, fontSize: 12),
              ),
            ),
          ),
          if (_searchHighlights.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              onPressed: () => _jumpToMatch(_currentMatchIndex - 1),
              color: Colors.grey.shade400,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              onPressed: () => _jumpToMatch(_currentMatchIndex + 1),
              color: Colors.grey.shade400,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _toggleSearchBar,
            color: Colors.grey.shade400,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
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
