import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Termux-style extra keys row for terminal
class ExtraKeysRow extends StatelessWidget {
  final List<String> keys;
  final Function(String) onKeyPress;
  final Function(int) onControlKey;
  final VoidCallback? onTab;
  final VoidCallback? onEscape;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;
  final bool hapticFeedback;

  const ExtraKeysRow({
    super.key,
    required this.keys,
    required this.onKeyPress,
    required this.onControlKey,
    this.onTab,
    this.onEscape,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
    this.hapticFeedback = true,
  });

  void _onTap(VoidCallback? action) {
    if (hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    action?.call();
  }

  void _handleKey(String key) {
    switch (key.toUpperCase()) {
      case 'ESC':
        _onTap(onEscape);
        break;
      case 'CTRL':
        _onTap(() => onControlKey(17));
        break;
      case 'ALT':
        _onTap(() => onControlKey(18));
        break;
      case 'TAB':
        _onTap(onTab);
        break;
      case 'UP':
        _onTap(onArrowUp);
        break;
      case 'DOWN':
        _onTap(onArrowDown);
        break;
      case 'LEFT':
        _onTap(onArrowLeft);
        break;
      case 'RIGHT':
        _onTap(onArrowRight);
        break;
      default:
        _onTap(() => onKeyPress(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          top: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                return _buildKeyItem(key);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyItem(String key) {
    final isSpecial = [
      'ESC',
      'CTRL',
      'ALT',
      'TAB',
      'UP',
      'DOWN',
      'LEFT',
      'RIGHT'
    ].contains(key.toUpperCase());

    Color? backgroundColor;
    Widget child;

    switch (key.toUpperCase()) {
      case 'ESC':
        backgroundColor = Colors.orange.shade800.withValues(alpha: 0.3);
        child = const Text('ESC', style: _textStyle);
        break;
      case 'CTRL':
        backgroundColor = Colors.blue.shade800.withValues(alpha: 0.3);
        child = const Text('CTRL', style: _textStyle);
        break;
      case 'ALT':
        backgroundColor = Colors.purple.shade800.withValues(alpha: 0.3);
        child = const Text('ALT', style: _textStyle);
        break;
      case 'TAB':
        backgroundColor = Colors.teal.shade800.withValues(alpha: 0.3);
        child = const Text('TAB', style: _textStyle);
        break;
      case 'UP':
        child =
            const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20);
        break;
      case 'DOWN':
        child = const Icon(Icons.keyboard_arrow_down,
            color: Colors.white, size: 20);
        break;
      case 'LEFT':
        child = const Icon(Icons.keyboard_arrow_left,
            color: Colors.white, size: 20);
        break;
      case 'RIGHT':
        child = const Icon(Icons.keyboard_arrow_right,
            color: Colors.white, size: 20);
        break;
      default:
        child = Text(key, style: _textStyle.copyWith(fontSize: 16));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKey(key),
        child: Container(
          width: isSpecial ? 64 : 44,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSpecial
                  ? Colors.blue.shade400.withValues(alpha: 0.3)
                  : Colors.grey.shade700,
              width: 1,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  static const _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
}
