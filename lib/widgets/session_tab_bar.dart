import 'package:flutter/material.dart';
import '../models/ssh_session.dart';

/// Tab bar for managing multiple SSH sessions
class SessionTabBar extends StatelessWidget {
  final List<SSHSessionModel> sessions;
  final int activeIndex;
  final Function(int) onTabSelected;
  final Function(int) onTabClosed;
  final VoidCallback onNewTab;

  const SessionTabBar({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Scrollable tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = index == activeIndex;
                return _buildTab(context, session, index, isActive);
              },
            ),
          ),
          // New tab button
          _buildNewTabButton(),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    SSHSessionModel session,
    int index,
    bool isActive,
  ) {
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 100,
          maxWidth: 180,
        ),
        margin: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.grey.shade800 : Colors.grey.shade700,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border.all(
            color: isActive ? Colors.grey.shade600 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            if (isActive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Connection status indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(session),
                      shape: BoxShape.circle,
                      boxShadow: session.isConnected
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tab title
                  Flexible(
                    child: Text(
                      session.displayName,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade400,
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Close button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTabClosed(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: isActive
                              ? Colors.grey.shade300
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTabButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onNewTab,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade600, width: 0.5),
          ),
          child: Icon(
            Icons.add,
            color: Colors.grey.shade300,
            size: 20,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(SSHSessionModel session) {
    if (session.isConnecting) {
      return Colors.yellow.shade600;
    }
    if (session.isConnected) {
      return Colors.green.shade500;
    }
    return Colors.grey.shade500;
  }
}
