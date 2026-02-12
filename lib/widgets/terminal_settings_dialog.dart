import 'package:flutter/material.dart';
import '../models/terminal_theme.dart';
import '../models/terminal_settings.dart';

/// Settings dialog for terminal configuration
class TerminalSettingsDialog extends StatefulWidget {
  final TerminalSettings settings;
  final Function(TerminalSettings) onSettingsChanged;

  const TerminalSettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required TerminalSettings settings,
    required Function(TerminalSettings) onSettingsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TerminalSettingsDialog(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<TerminalSettingsDialog> createState() => _TerminalSettingsDialogState();
}

class _TerminalSettingsDialogState extends State<TerminalSettingsDialog> {
  late TerminalSettings _settings;
  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settings = widget.settings.copyWith();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _updateSettings(TerminalSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.blue.shade400),
                    const SizedBox(width: 12),
                    const Text(
                      'Terminal Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey.shade700),
              // Settings content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFontSizeSection(),
                    const SizedBox(height: 24),
                    _buildThemeSection(),
                    const SizedBox(height: 24),
                    _buildToggleSection(),
                    const SizedBox(height: 24),
                    _buildExtraKeysSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Font Size', Icons.format_size),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decrease button
                  IconButton(
                    onPressed: _settings.fontSize > TerminalSettings.minFontSize
                        ? () {
                            _settings.decreaseFontSize();
                            _updateSettings(_settings);
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 32,
                    color: Colors.blue.shade400,
                    disabledColor: Colors.grey.shade600,
                  ),
                  // Current size display
                  Column(
                    children: [
                      Text(
                        '${_settings.fontSize.toInt()}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'px',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  // Increase button
                  IconButton(
                    onPressed: _settings.fontSize < TerminalSettings.maxFontSize
                        ? () {
                            _settings.increaseFontSize();
                            _updateSettings(_settings);
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 32,
                    color: Colors.blue.shade400,
                    disabledColor: Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Slider
              Slider(
                value: _settings.fontSize,
                min: TerminalSettings.minFontSize,
                max: TerminalSettings.maxFontSize,
                divisions: (TerminalSettings.maxFontSize -
                        TerminalSettings.minFontSize)
                    .toInt(),
                label: '${_settings.fontSize.toInt()} px',
                activeColor: Colors.blue.shade400,
                inactiveColor: Colors.grey.shade600,
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(fontSize: value));
                },
              ),
              // Reset button
              TextButton(
                onPressed: () {
                  _settings.resetFontSize();
                  _updateSettings(_settings);
                },
                child: Text(
                  'Reset to Default',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Color Theme', Icons.palette),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: AppTerminalTheme.allThemes.length,
          itemBuilder: (context, index) {
            final theme = AppTerminalTheme.allThemes[index];
            final isSelected = theme.id == _settings.themeId;
            return _buildThemeCard(theme, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildThemeCard(AppTerminalTheme theme, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _updateSettings(_settings.copyWith(themeId: theme.id));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Theme preview
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$ ls',
                      style: TextStyle(
                        color: theme.foreground,
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'file.txt',
                      style: TextStyle(
                        color: theme.green,
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'error',
                      style: TextStyle(
                        color: theme.red,
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Theme name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: Text(
                theme.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Options', Icons.tune),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildToggleTile(
                title: 'Show Extra Keys',
                subtitle: 'Display ESC, CTRL, ALT, TAB keyboard row',
                icon: Icons.keyboard,
                value: _settings.showExtraKeys,
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(showExtraKeys: value));
                },
              ),
              Divider(color: Colors.grey.shade700, height: 1),
              _buildToggleTile(
                title: 'Haptic Feedback',
                subtitle: 'Vibrate on key press',
                icon: Icons.vibration,
                value: _settings.hapticFeedback,
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(hapticFeedback: value));
                },
              ),
              Divider(color: Colors.grey.shade700, height: 1),
              _buildToggleTile(
                title: 'Bell Sound',
                subtitle: 'Play sound on terminal bell',
                icon: Icons.notifications,
                value: _settings.bellEnabled,
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(bellEnabled: value));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade400),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Colors.blue.shade400,
      ),
    );
  }

  Widget _buildExtraKeysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Additional Keys', Icons.keyboard_alt),
        const SizedBox(height: 12),
        Text(
          'Customize symbols and special keys show in the extra row',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _settings.extraKeys.map((key) {
                  return InputChip(
                    label: Text(key),
                    onDeleted: () {
                      final newKeys = List<String>.from(_settings.extraKeys);
                      newKeys.remove(key);
                      _updateSettings(_settings.copyWith(extraKeys: newKeys));
                    },
                    backgroundColor: Colors.grey.shade700,
                    deleteIconColor: Colors.red.shade300,
                    labelStyle:
                        const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        hintText: 'Add new key (e.g., @, #, F1)',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_keyController.text.isNotEmpty) {
                        final newKeys = List<String>.from(_settings.extraKeys);
                        newKeys.add(_keyController.text.trim());
                        _updateSettings(_settings.copyWith(extraKeys: newKeys));
                        _keyController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Available special labels: ESC, CTRL, ALT, TAB, UP, DOWN, LEFT, RIGHT',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
