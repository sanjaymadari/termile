import 'package:flutter/material.dart';

/// Dropdown widget for selecting SSH keys
class SshKeyDropdown extends StatelessWidget {
  final List<Map<String, String>> availableKeys;
  final String? selectedKeyPath;
  final Function(Map<String, String>) onKeySelected;
  final VoidCallback onImportKey;

  const SshKeyDropdown({
    super.key,
    required this.availableKeys,
    required this.selectedKeyPath,
    required this.onKeySelected,
    required this.onImportKey,
  });

  @override
  Widget build(BuildContext context) {
    if (availableKeys.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.vpn_key, color: Colors.blue.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SSH Key',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onImportKey,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Import'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          // Keys list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: availableKeys.length,
              itemBuilder: (context, index) {
                final key = availableKeys[index];
                final isSelected = key['privatePath'] == selectedKeyPath;

                return _KeyListTile(
                  keyInfo: key,
                  isSelected: isSelected,
                  onTap: () => onKeySelected(key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: Column(
        children: [
          Icon(Icons.vpn_key_off, color: Colors.grey.shade500, size: 40),
          const SizedBox(height: 12),
          Text(
            'No SSH Keys Found',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import an SSH key to connect securely',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onImportKey,
            icon: const Icon(Icons.file_upload),
            label: const Text('Import SSH Key'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual key list tile
class _KeyListTile extends StatelessWidget {
  final Map<String, String> keyInfo;
  final bool isSelected;
  final VoidCallback onTap;

  const _KeyListTile({
    required this.keyInfo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = keyInfo['name'] ?? 'Unknown';
    final type = keyInfo['type'] ?? 'Imported';
    final timestamp = keyInfo['timestamp'] ?? '';

    // Parse timestamp to readable date
    String dateStr = '';
    if (timestamp.isNotEmpty && timestamp != 'Unknown') {
      try {
        final ms = int.parse(timestamp);
        final date = DateTime.fromMillisecondsSinceEpoch(ms);
        dateStr = '${date.day}/${date.month}/${date.year}';
      } catch (_) {
        dateStr = timestamp;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withValues(alpha: 0.15) : null,
            border: isSelected
                ? Border(
                    left: BorderSide(color: Colors.blue.shade400, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Key icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.shade700
                      : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.vpn_key,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // Key info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade300,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildBadge(
                          type,
                          type == 'Imported' ? Colors.purple : Colors.green,
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade400,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
