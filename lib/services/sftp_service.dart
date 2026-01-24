import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

/// Model representing a remote file or directory
class RemoteFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modifiedTime;
  final String? permissions;
  final String? owner;
  final String? group;

  RemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modifiedTime,
    this.permissions,
    this.owner,
    this.group,
  });

  /// Get file extension
  String get extension {
    if (isDirectory) return '';
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Get human-readable file size
  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check if file is a text file
  bool get isTextFile {
    const textExtensions = [
      'txt',
      'md',
      'json',
      'xml',
      'yaml',
      'yml',
      'ini',
      'cfg',
      'conf',
      'log',
      'sh',
      'bash',
      'zsh',
      'py',
      'js',
      'ts',
      'dart',
      'java',
      'kt',
      'swift',
      'c',
      'cpp',
      'h',
      'hpp',
      'rs',
      'go',
      'rb',
      'php',
      'html',
      'css',
      'scss',
      'less',
      'sql',
      'env',
      'gitignore',
      'dockerfile',
    ];
    return textExtensions.contains(extension);
  }

  /// Check if file is an image
  bool get isImage {
    const imageExtensions = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'svg',
      'ico',
    ];
    return imageExtensions.contains(extension);
  }

  /// Check if file is an archive
  bool get isArchive {
    const archiveExtensions = ['zip', 'tar', 'gz', 'bz2', 'xz', '7z', 'rar'];
    return archiveExtensions.contains(extension);
  }

  /// Parse from SFTP file attributes
  factory RemoteFile.fromSftpName(SftpName sftpName, String parentPath) {
    final attrs = sftpName.attr;
    final isDir = attrs.isDirectory;

    return RemoteFile(
      name: sftpName.filename,
      path: parentPath.endsWith('/')
          ? '$parentPath${sftpName.filename}'
          : '$parentPath/${sftpName.filename}',
      isDirectory: isDir,
      size: attrs.size ?? 0,
      modifiedTime: attrs.modifyTime != null
          ? DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000)
          : null,
      permissions: _formatPermissions(attrs.mode),
      owner: attrs.userID?.toString(),
      group: attrs.groupID?.toString(),
    );
  }

  /// Format Unix permissions to string from mode value
  static String? _formatPermissions(SftpFileMode? mode) {
    if (mode == null) return null;

    // Get the numeric value and format as octal permissions string
    final value = mode.value;

    String result = '';

    // Owner permissions (bits 8-6)
    result += ((value >> 6) & 4) != 0 ? 'r' : '-';
    result += ((value >> 6) & 2) != 0 ? 'w' : '-';
    result += ((value >> 6) & 1) != 0 ? 'x' : '-';

    // Group permissions (bits 5-3)
    result += ((value >> 3) & 4) != 0 ? 'r' : '-';
    result += ((value >> 3) & 2) != 0 ? 'w' : '-';
    result += ((value >> 3) & 1) != 0 ? 'x' : '-';

    // Other permissions (bits 2-0)
    result += (value & 4) != 0 ? 'r' : '-';
    result += (value & 2) != 0 ? 'w' : '-';
    result += (value & 1) != 0 ? 'x' : '-';

    return result;
  }
}

/// SFTP service for file operations
class SftpService {
  final SftpClient _sftp;
  String _currentPath = '/';

  SftpService(this._sftp);

  /// Get current directory path
  String get currentPath => _currentPath;

  /// List files in a directory
  Future<List<RemoteFile>> listDirectory(String path) async {
    try {
      final items = await _sftp.listdir(path);
      final files = <RemoteFile>[];

      for (final item in items) {
        // Skip . and ..
        if (item.filename == '.' || item.filename == '..') continue;
        files.add(RemoteFile.fromSftpName(item, path));
      }

      // Sort: directories first, then by name
      files.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _currentPath = path;
      return files;
    } catch (e) {
      throw Exception('Failed to list directory: $e');
    }
  }

  /// Navigate to a directory
  Future<List<RemoteFile>> navigateTo(String path) async {
    return listDirectory(path);
  }

  /// Navigate to parent directory
  Future<List<RemoteFile>> navigateUp() async {
    if (_currentPath == '/') return listDirectory('/');

    final parts = _currentPath.split('/');
    parts.removeLast();
    final parentPath = parts.isEmpty ? '/' : parts.join('/');

    return listDirectory(parentPath.isEmpty ? '/' : parentPath);
  }

  /// Download a file
  Future<Uint8List> downloadFile(String remotePath) async {
    try {
      final file = await _sftp.open(remotePath);
      final data = await file.readBytes();
      await file.close();
      return data;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  /// Download file to local path
  Future<void> downloadFileTo(String remotePath, String localPath) async {
    try {
      final data = await downloadFile(remotePath);
      await File(localPath).writeAsBytes(data);
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  /// Upload a file
  Future<void> uploadFile(String localPath, String remotePath) async {
    try {
      final localFile = File(localPath);
      final data = await localFile.readAsBytes();

      final remoteFile = await _sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      await remoteFile.writeBytes(data);
      await remoteFile.close();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Create a new directory
  Future<void> createDirectory(String path) async {
    try {
      await _sftp.mkdir(path);
    } catch (e) {
      throw Exception('Failed to create directory: $e');
    }
  }

  /// Delete a file
  Future<void> deleteFile(String path) async {
    try {
      await _sftp.remove(path);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Delete a directory
  Future<void> deleteDirectory(String path) async {
    try {
      await _sftp.rmdir(path);
    } catch (e) {
      throw Exception('Failed to delete directory: $e');
    }
  }

  /// Rename a file or directory
  Future<void> rename(String oldPath, String newPath) async {
    try {
      await _sftp.rename(oldPath, newPath);
    } catch (e) {
      throw Exception('Failed to rename: $e');
    }
  }

  /// Get file info
  Future<RemoteFile> getFileInfo(String path) async {
    try {
      final stat = await _sftp.stat(path);
      final name = path.split('/').last;

      return RemoteFile(
        name: name,
        path: path,
        isDirectory: stat.isDirectory,
        size: stat.size ?? 0,
        modifiedTime: stat.modifyTime != null
            ? DateTime.fromMillisecondsSinceEpoch(stat.modifyTime! * 1000)
            : null,
      );
    } catch (e) {
      throw Exception('Failed to get file info: $e');
    }
  }

  /// Read text file content
  Future<String> readTextFile(String path) async {
    try {
      final data = await downloadFile(path);
      return String.fromCharCodes(data);
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  /// Write text file content
  Future<void> writeTextFile(String path, String content) async {
    try {
      final file = await _sftp.open(
        path,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      await file.writeBytes(Uint8List.fromList(content.codeUnits));
      await file.close();
    } catch (e) {
      throw Exception('Failed to write file: $e');
    }
  }

  /// Close SFTP connection
  void close() {
    _sftp.close();
  }
}
