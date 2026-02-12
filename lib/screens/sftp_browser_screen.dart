import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/sftp_service.dart';

/// SFTP File Browser Screen
class SftpBrowserScreen extends StatefulWidget {
  final SftpService sftp;
  final String initialPath;

  const SftpBrowserScreen({
    super.key,
    required this.sftp,
    this.initialPath = '/',
  });

  @override
  State<SftpBrowserScreen> createState() => _SftpBrowserScreenState();
}

class _SftpBrowserScreenState extends State<SftpBrowserScreen> {
  List<RemoteFile> _files = [];
  bool _isLoading = true;
  String _currentPath = '/';
  String? _error;
  final Set<String> _selectedFiles = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedFiles.clear();
      _selectionMode = false;
    });

    try {
      final files = await widget.sftp.listDirectory(path);
      setState(() {
        _files = files;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateUp() async {
    if (_currentPath == '/') return;

    final parts = _currentPath.split('/');
    parts.removeLast();
    final parentPath = parts.join('/');

    await _loadDirectory(parentPath.isEmpty ? '/' : parentPath);
  }

  Future<void> _onFileTap(RemoteFile file) async {
    if (_selectionMode) {
      setState(() {
        if (_selectedFiles.contains(file.path)) {
          _selectedFiles.remove(file.path);
          if (_selectedFiles.isEmpty) _selectionMode = false;
        } else {
          _selectedFiles.add(file.path);
        }
      });
      return;
    }

    if (file.isDirectory) {
      await _loadDirectory(file.path);
    } else {
      _showFileActions(file);
    }
  }

  void _onFileLongPress(RemoteFile file) {
    setState(() {
      _selectionMode = true;
      _selectedFiles.add(file.path);
    });
  }

  void _showFileActions(RemoteFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FileActionsSheet(
        file: file,
        onDownload: () => _downloadFile(file),
        onDelete: () => _deleteFile(file),
        onRename: () => _showRenameDialog(file),
        onViewContent: file.isTextFile ? () => _viewFileContent(file) : null,
      ),
    );
  }

  Future<void> _downloadFile(RemoteFile file) async {
    Navigator.pop(context);

    _showLoadingDialog('Downloading ${file.name}...');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final localPath = '${downloadsDir.path}/${file.name}';
      await widget.sftp.downloadFileTo(file.path, localPath);

      if (mounted) Navigator.pop(context); // Close loading dialog

      _showSuccessSnackbar('Downloaded to $localPath');

      // Offer to share
      if (mounted) {
        final share = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Complete'),
            content: Text(
              '${file.name} has been downloaded. Would you like to share it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Share'),
              ),
            ],
          ),
        );

        if (share == true) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(localPath)],
              subject: 'Sharing ${file.name} from Termile',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Download failed: $e');
    }
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      final file = result.files.single;
      if (file.path == null) return;

      _showLoadingDialog('Uploading ${file.name}...');

      final remotePath = '$_currentPath/${file.name}';
      await widget.sftp.uploadFile(file.path!, remotePath);

      if (mounted) Navigator.pop(context); // Close loading dialog

      _showSuccessSnackbar('Uploaded ${file.name}');
      await _loadDirectory(_currentPath);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Upload failed: $e');
    }
  }

  Future<void> _deleteFile(RemoteFile file) async {
    Navigator.pop(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog('Deleting ${file.name}...');

    try {
      if (file.isDirectory) {
        await widget.sftp.deleteDirectory(file.path);
      } else {
        await widget.sftp.deleteFile(file.path);
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      _showSuccessSnackbar('Deleted ${file.name}');
      await _loadDirectory(_currentPath);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Delete failed: $e');
    }
  }

  Future<void> _showRenameDialog(RemoteFile file) async {
    Navigator.pop(context);

    final controller = TextEditingController(text: file.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == file.name) return;

    _showLoadingDialog('Renaming...');

    try {
      final parentPath = file.path.substring(
        0,
        file.path.length - file.name.length,
      );
      final newPath = '$parentPath$newName';
      await widget.sftp.rename(file.path, newPath);

      if (mounted) Navigator.pop(context); // Close loading dialog

      _showSuccessSnackbar('Renamed to $newName');
      await _loadDirectory(_currentPath);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Rename failed: $e');
    }
  }

  Future<void> _createDirectory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    _showLoadingDialog('Creating folder...');

    try {
      await widget.sftp.createDirectory('$_currentPath/$name');

      if (mounted) Navigator.pop(context); // Close loading dialog

      _showSuccessSnackbar('Created folder: $name');
      await _loadDirectory(_currentPath);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Create folder failed: $e');
    }
  }

  Future<void> _viewFileContent(RemoteFile file) async {
    Navigator.pop(context);

    _showLoadingDialog('Loading file...');

    try {
      final content = await widget.sftp.readTextFile(file.path);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _FileViewerScreen(
              fileName: file.name,
              content: content,
              onSave: (newContent) => _saveFileContent(file.path, newContent),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Failed to read file: $e');
    }
  }

  Future<void> _saveFileContent(String path, String content) async {
    _showLoadingDialog('Saving...');

    try {
      await widget.sftp.writeTextFile(path, content);

      if (mounted) Navigator.pop(context); // Close loading dialog

      _showSuccessSnackbar('File saved');
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorSnackbar('Save failed: $e');
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

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    widget.sftp.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SFTP Browser',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _currentPath,
              style: TextStyle(fontSize: 11, color: Colors.blue.shade300),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedFiles.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: _createDirectory,
              tooltip: 'New Folder',
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _uploadFile,
              tooltip: 'Upload File',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadDirectory(_currentPath),
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb / Path bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Row(
              children: [
                // Home button
                InkWell(
                  onTap: () => _loadDirectory('/'),
                  child: const Icon(Icons.home, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                // Up button
                if (_currentPath != '/')
                  InkWell(
                    onTap: _navigateUp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Up',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.grey.shade400),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadDirectory(_currentPath),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _files.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  size: 48,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Empty folder',
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _files.length,
                            itemBuilder: (context, index) {
                              final file = _files[index];
                              final isSelected =
                                  _selectedFiles.contains(file.path);

                              return _FileListTile(
                                file: file,
                                isSelected: isSelected,
                                onTap: () => _onFileTap(file),
                                onLongPress: () => _onFileLongPress(file),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// File list tile widget
class _FileListTile extends StatelessWidget {
  final RemoteFile file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileListTile({
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _getFileIcon() {
    if (file.isDirectory) return Icons.folder;
    if (file.isImage) return Icons.image;
    if (file.isArchive) return Icons.archive;
    if (file.isTextFile) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getIconColor() {
    if (file.isDirectory) return Colors.amber;
    if (file.isImage) return Colors.purple;
    if (file.isArchive) return Colors.orange;
    if (file.isTextFile) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.grey.shade800.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getIconColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _getIconColor().withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(_getFileIcon(), color: _getIconColor(), size: 24),
        ),
        title: Text(
          file.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              file.formattedSize,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            if (file.permissions != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  file.permissions!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.blue.shade400)
            : file.isDirectory
                ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
                : null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// File actions bottom sheet
class _FileActionsSheet extends StatelessWidget {
  final RemoteFile file;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onViewContent;

  const _FileActionsSheet({
    required this.file,
    required this.onDownload,
    required this.onDelete,
    required this.onRename,
    this.onViewContent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File info header
          Row(
            children: [
              Icon(
                file.isDirectory ? Icons.folder : Icons.insert_drive_file,
                color: file.isDirectory ? Colors.amber : Colors.blue,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      file.formattedSize,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 8),
          // Actions
          if (onViewContent != null)
            _ActionTile(
              icon: Icons.visibility,
              label: 'View / Edit',
              onTap: onViewContent!,
            ),
          if (!file.isDirectory)
            _ActionTile(
              icon: Icons.download,
              label: 'Download',
              onTap: onDownload,
            ),
          _ActionTile(
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
            onTap: onRename,
          ),
          _ActionTile(
            icon: Icons.delete,
            label: 'Delete',
            color: Colors.red,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Action tile for bottom sheet
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(label, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
    );
  }
}

/// File viewer/editor screen
class _FileViewerScreen extends StatefulWidget {
  final String fileName;
  final String content;
  final Function(String) onSave;

  const _FileViewerScreen({
    required this.fileName,
    required this.content,
    required this.onSave,
  });

  @override
  State<_FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<_FileViewerScreen> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _controller.addListener(() {
      if (!_hasChanges && _controller.text != widget.content) {
        setState(() => _hasChanges = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to save them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              widget.onSave(_controller.text);
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade900,
        appBar: AppBar(
          backgroundColor: Colors.grey.shade900,
          title: Text(widget.fileName),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  widget.onSave(_controller.text);
                  setState(() => _hasChanges = false);
                },
                tooltip: 'Save',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            maxLines: null,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white,
            ),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ),
    );
  }
}
