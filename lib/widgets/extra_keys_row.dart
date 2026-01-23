import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Termux-style extra keys row for terminal
class ExtraKeysRow extends StatelessWidget {
  final Function(String) onKeyPress;
  final Function(int) onControlKey;
  final VoidCallback? onCtrlC;
  final VoidCallback? onTab;
  final VoidCallback? onEscape;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;
  final bool hapticFeedback;

  const ExtraKeysRow({
    super.key,
    required this.onKeyPress,
    required this.onControlKey,
    this.onCtrlC,
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
          // Main extra keys row
          SizedBox(
            height: 44,
            child: Row(
              children: [
                _buildKey(
                  'ESC',
                  onTap: () => _onTap(onEscape),
                  color: Colors.orange.shade700,
                ),
                _buildKey(
                  'CTRL',
                  onTap: () => _onTap(() => onControlKey(17)), // Ctrl key code
                  color: Colors.blue.shade700,
                ),
                _buildKey(
                  'ALT',
                  onTap: () => _onTap(() => onControlKey(18)), // Alt key code
                  color: Colors.purple.shade700,
                ),
                _buildKey(
                  'TAB',
                  onTap: () => _onTap(onTab),
                  color: Colors.teal.shade700,
                ),
                _buildDivider(),
                _buildArrowKey(Icons.keyboard_arrow_up,
                    onTap: () => _onTap(onArrowUp)),
                _buildArrowKey(Icons.keyboard_arrow_down,
                    onTap: () => _onTap(onArrowDown)),
                _buildArrowKey(Icons.keyboard_arrow_left,
                    onTap: () => _onTap(onArrowLeft)),
                _buildArrowKey(Icons.keyboard_arrow_right,
                    onTap: () => _onTap(onArrowRight)),
              ],
            ),
          ),
          // Quick keys row
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _buildQuickKey('|', onTap: () => _onTap(() => onKeyPress('|'))),
                _buildQuickKey('/', onTap: () => _onTap(() => onKeyPress('/'))),
                _buildQuickKey('~', onTap: () => _onTap(() => onKeyPress('~'))),
                _buildQuickKey('-', onTap: () => _onTap(() => onKeyPress('-'))),
                _buildQuickKey('_', onTap: () => _onTap(() => onKeyPress('_'))),
                _buildQuickKey('{', onTap: () => _onTap(() => onKeyPress('{'))),
                _buildQuickKey('}', onTap: () => _onTap(() => onKeyPress('}'))),
                _buildQuickKey('[', onTap: () => _onTap(() => onKeyPress('['))),
                _buildQuickKey(']', onTap: () => _onTap(() => onKeyPress(']'))),
                _buildQuickKey('\$',
                    onTap: () => _onTap(() => onKeyPress('\$'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(
    String label, {
    required VoidCallback onTap,
    Color? color,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade600, width: 0.5),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrowKey(IconData icon, {required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade600, width: 0.5),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickKey(String label, {required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey.shade700,
    );
  }
}
