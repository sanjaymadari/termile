import 'package:flutter/material.dart';
import '../models/command_snippet.dart';
import '../services/snippet_service.dart';

class SnippetPickerSheet extends StatefulWidget {
  final Function(CommandSnippet) onSnippetSelected;

  const SnippetPickerSheet({
    super.key,
    required this.onSnippetSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(CommandSnippet) onSnippetSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SnippetPickerSheet(onSnippetSelected: onSnippetSelected),
    );
  }

  @override
  State<SnippetPickerSheet> createState() => _SnippetPickerSheetState();
}

class _SnippetPickerSheetState extends State<SnippetPickerSheet> {
  List<CommandSnippet>? _snippets;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await SnippetService.loadSnippets();
    if (mounted) {
      setState(() {
        _snippets = data;
        _isLoading = false;
      });
    }
  }

  void _addNewSnippet() {
    final nameController = TextEditingController();
    final cmdController = TextEditingController();
    bool autoExec = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title:
              const Text('Add Snippet', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cmdController,
                decoration: InputDecoration(
                  labelText: 'Command',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-Execute',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('Add enter after command',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                value: autoExec,
                onChanged: (val) => setDialogState(() => autoExec = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    cmdController.text.isNotEmpty) {
                  final snippet = CommandSnippet(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    command: cmdController.text,
                    autoExecute: autoExec,
                  );
                  await SnippetService.addSnippet(snippet);
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Command Snippets',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: _addNewSnippet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_snippets == null || _snippets!.isEmpty)
            const Center(
                child: Text('No snippets found',
                    style: TextStyle(color: Colors.grey)))
          else
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: _snippets!.length,
                itemBuilder: (context, index) {
                  final s = _snippets![index];
                  return _buildSnippetCard(s);
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSnippetCard(CommandSnippet snippet) {
    return InkWell(
      onTap: () {
        widget.onSnippetSelected(snippet);
        Navigator.pop(context);
      },
      onLongPress: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text('Delete Snippet?',
                style: TextStyle(color: Colors.white)),
            content: Text('Remove "${snippet.name}"?',
                style: const TextStyle(color: Colors.grey)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes')),
            ],
          ),
        );
        if (confirm == true) {
          await SnippetService.deleteSnippet(snippet.id);
          _loadData();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade700, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snippet.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              snippet.command,
              style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 11,
                  fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
