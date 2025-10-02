import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:termile/connection_profile.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SSH Terminal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey.shade900,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
          ),
        ),
      ),
      home: const SSHTerminal(),
    );
  }
}

class SSHTerminal extends StatefulWidget {
  const SSHTerminal({super.key});

  @override
  State<SSHTerminal> createState() => _SSHTerminalState();
}

class _SSHTerminalState extends State<SSHTerminal> {
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _passwordController = TextEditingController();
  final _profileNameController = TextEditingController();
  final _terminal = Terminal();
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _privateKeyPath;
  String? _privateKeyContent;
  // String? _publicKeyContent;
  // String? _publicKeyPath;
  List<ConnectionProfile> _savedProfiles = [];
  List<Map<String, String>> _availableKeys = []; // List of available key pairs
  bool _usePasswordAuth = false; // Toggle between key and password auth

  @override
  void initState() {
    super.initState();
    _checkExistingKeys();
    _loadSavedProfiles();
    _loadAvailableKeys();
  }

  // Handle keyboard shortcuts
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _isConnected) {
      // Handle Escape key as Ctrl+C
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _session?.write(Uint8List.fromList([3])); // Send Ctrl+C
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _session?.close();
    _client?.close();
    super.dispose();
  }

  // Load saved connection profiles
  Future<void> _loadSavedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString('connection_profiles');
      if (profilesJson != null) {
        final List<dynamic> profiles = jsonDecode(profilesJson);
        setState(() {
          _savedProfiles = profiles
              .map((profile) => ConnectionProfile.fromJson(profile))
              .toList();
        });
      }
    } catch (e) {
      _showError('Error loading profiles: $e');
    }
  }

  // Save connection profiles
  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson =
          jsonEncode(_savedProfiles.map((p) => p.toJson()).toList());
      await prefs.setString('connection_profiles', profilesJson);
    } catch (e) {
      _showError('Error saving profiles: $e');
    }
  }

  // Save current connection as profile
  Future<void> _saveCurrentProfile() async {
    final List<String> missingFields = [];

    if (_ipController.text.isEmpty) {
      missingFields.add('IP Address');
    }
    if (_usernameController.text.isEmpty) {
      missingFields.add('Username');
    }
    if (_portController.text.isEmpty) {
      missingFields.add('Port');
    } else {
      final port = int.tryParse(_portController.text);
      if (port == null || port < 1 || port > 65535) {
        missingFields.add('Valid Port (1-65535)');
      }
    }
    if (_usePasswordAuth) {
      if (_passwordController.text.isEmpty) {
        missingFields.add('Password');
      }
    } else {
      if (_privateKeyPath == null) {
        missingFields.add('SSH Key');
      }
    }

    if (missingFields.isNotEmpty) {
      _showError('Please fill in: ${missingFields.join(', ')}');
      return;
    }

    // Show dialog to enter profile name
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Connection Profile'),
        content: TextField(
          controller: _profileNameController,
          decoration: const InputDecoration(
            labelText: 'Profile Name',
            hintText: 'e.g., Development Server',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_profileNameController.text.isEmpty) {
                _showError('Please enter a profile name');
                return;
              }

              final newProfile = ConnectionProfile(
                name: _profileNameController.text,
                host: _ipController.text,
                username: _usernameController.text,
                port: int.parse(_portController.text),
                keyPath: _usePasswordAuth ? '' : _privateKeyPath!,
                usePasswordAuth: _usePasswordAuth,
                password: _usePasswordAuth ? _passwordController.text : null,
              );

              setState(() {
                _savedProfiles.add(newProfile);
              });
              await _saveProfiles();
              _profileNameController.clear();
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              _showSuccess('Profile saved successfully');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Load a saved profile
  void _loadProfile(ConnectionProfile profile) {
    setState(() {
      _ipController.text = profile.host;
      _usernameController.text = profile.username;
      _portController.text = profile.port.toString();
      _usePasswordAuth = profile.usePasswordAuth;
      if (profile.usePasswordAuth) {
        _passwordController.text = profile.password ?? '';
        _privateKeyPath = null;
        _privateKeyContent = null;
        // _publicKeyContent = null;
        // _publicKeyPath = null;
      } else {
        _privateKeyPath = profile.keyPath;
        _passwordController.clear();
        // Load the key content
        if (profile.keyPath.isNotEmpty) {
          File(profile.keyPath).readAsString().then((content) {
            _privateKeyContent = content;
          }).catchError((error) {
            _showError('Error loading key: $error');
          });
        }
      }
    });
  }

  // Delete a saved profile
  Future<void> _deleteProfile(ConnectionProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _savedProfiles.removeWhere((p) => p.name == profile.name);
      });
      await _saveProfiles();
      _showSuccess('Profile deleted');
    }
  }

  Future<void> _checkExistingKeys() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final keysDir = Directory('${directory.path}/ssh_keys');

      if (await keysDir.exists()) {
        final files = await keysDir.list().toList();
        final privateKeyFiles = files
            .where((file) =>
                file is File &&
                !file.path.endsWith('.pub') &&
                (file.path.contains('id_rsa') ||
                    file.path.contains('imported')))
            .cast<File>()
            .toList();

        if (privateKeyFiles.isNotEmpty) {
          // Use the most recent key file
          privateKeyFiles.sort((a, b) => b.path.compareTo(a.path));
          final privateKeyFile = privateKeyFiles.first;
          final publicKeyFile = File('${privateKeyFile.path}.pub');

          if (await publicKeyFile.exists()) {
            _privateKeyPath = privateKeyFile.path;
            _privateKeyContent = await privateKeyFile.readAsString();
            // _publicKeyContent = await publicKeyFile.readAsString();
            // _publicKeyPath = publicKeyFile.path;
            setState(() {});
          }
        }
      }
    } catch (e) {
      _showError('Error checking existing keys: $e');
    }
  }

  Future<void> _loadAvailableKeys() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final keysDir = Directory('${directory.path}/ssh_keys');

      if (await keysDir.exists()) {
        final files = await keysDir.list().toList();
        final privateKeyFiles = files
            .where((file) =>
                file is File &&
                !file.path.endsWith('.pub') &&
                (file.path.contains('id_rsa') ||
                    file.path.contains('imported')))
            .cast<File>()
            .toList();

        final availableKeys = <Map<String, String>>[];

        for (final privateKeyFile in privateKeyFiles) {
          final publicKeyFile = File('${privateKeyFile.path}.pub');

          if (await publicKeyFile.exists()) {
            final fileName = privateKeyFile.path.split('/').last;
            final keyType =
                fileName.contains('imported') ? 'Imported' : 'Generated';
            final timestamp =
                fileName.contains('_') ? fileName.split('_').last : 'Unknown';

            availableKeys.add({
              'privatePath': privateKeyFile.path,
              'publicPath': publicKeyFile.path,
              'name': fileName,
              'type': keyType,
              'timestamp': timestamp,
            });
          }
        }

        // Sort by timestamp (newest first)
        availableKeys
            .sort((a, b) => b['timestamp']!.compareTo(a['timestamp']!));

        setState(() {
          _availableKeys = availableKeys;
        });
      }
    } catch (e) {
      _showError('Error loading available keys: $e');
    }
  }

//   Future<void> _generateKeyPair() async {
//     try {
//       setState(() => _isConnecting = true);

//       // For now, we'll create a placeholder key generation
//       // In a real implementation, you would use a proper crypto library
//       // or call native platform APIs for key generation

//       final directory = await getApplicationDocumentsDirectory();
//       final keysDir = Directory('${directory.path}/ssh_keys');
//       if (!await keysDir.exists()) {
//         await keysDir.create(recursive: true);
//       }

//       final timestamp = DateTime.now().millisecondsSinceEpoch;

//       // Generate a simple placeholder key pair
//       // Note: This is a simplified example - in production, use proper crypto libraries
//       final privateKeyContent = '''-----BEGIN RSA PRIVATE KEY-----
// MIIEpAIBAAKCAQEA7ExamplePrivateKeyContentHere
// ThisIsJustAPlaceholderForDemoPurposes
// InRealImplementationUseProperCryptoLibrary
// -----END RSA PRIVATE KEY-----''';

//       final publicKeyContent =
//           'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD7ExamplePublicKeyContentHere generated by termile app';

//       // Save private key
//       final privateKeyFile = File('${keysDir.path}/id_rsa_$timestamp');
//       await privateKeyFile.writeAsString(privateKeyContent);
//       _privateKeyPath = privateKeyFile.path;
//       _privateKeyContent = privateKeyContent;

//       // Save public key
//       final publicKeyFile = File('${keysDir.path}/id_rsa_$timestamp.pub');
//       await publicKeyFile.writeAsString(publicKeyContent);
//       _publicKeyContent = publicKeyContent;
//       _publicKeyPath = publicKeyFile.path;

//       setState(() => _isConnecting = false);

//       // Refresh available keys
//       await _loadAvailableKeys();

//       if (!mounted) return;
//       _showSuccess(
//           'SSH key pair generated successfully!\nPrivate: ${privateKeyFile.path}\nPublic: ${publicKeyFile.path}\nNote: This is a demo key. Use proper crypto libraries for production.');
//     } catch (e) {
//       setState(() => _isConnecting = false);
//       _showError('Error generating key pair: $e');
//     }
//   }

  // Future<void> _sharePublicKey() async {
  //   if (_publicKeyContent == null) {
  //     _showError('No public key available');
  //     return;
  //   }

  //   try {
  //     final directory = await getApplicationDocumentsDirectory();
  //     final tempFile = File('${directory.path}/id_rsa.pub');
  //     await tempFile.writeAsString(_publicKeyContent!);

  //     await SharePlus.instance.share(ShareParams(
  //       text: 'My SSH public key',
  //       files: [XFile(tempFile.path)],
  //     ));
  //   } catch (e) {
  //     _showError('Error sharing public key: $e');
  //   }
  // }

  Future<void> _importExistingKeys() async {
    try {
      // Pick private key
      final privateResult = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select private key (id_rsa)',
        // type: FileType.custom,
        // allowedExtensions: ['pem', 'key', 'rsa'],
      );
      if (privateResult == null) return;

      // Pick public key
      // final publicResult = await FilePicker.platform.pickFiles(
      //   dialogTitle: 'Select public key (id_rsa.pub)',
      //   // type: FileType.custom,
      //   // allowedExtensions: ['pub'],
      // );
      // if (publicResult == null) return;

      // Read and validate keys
      final privateKey =
          await File(privateResult.files.single.path!).readAsString();
      // final publicKey =
      //     await File(publicResult.files.single.path!).readAsString();

      // Validate key formats
      if (!privateKey.contains('BEGIN') ||
          !privateKey.contains('PRIVATE KEY')) {
        _showError('Invalid private key format');
        return;
      }
      // if (!publicKey.contains('ssh-rsa') &&
      //     !publicKey.contains('ssh-ed25519')) {
      //   _showError('Invalid public key format');
      //   return;
      // }

      // Save keys to dedicated directory
      final directory = await getApplicationDocumentsDirectory();
      final keysDir = Directory('${directory.path}/ssh_keys');
      if (!await keysDir.exists()) {
        await keysDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${keysDir.path}/imported_$timestamp';

      await File(filePath).writeAsString(privateKey);
      // await File('$filePath.pub').writeAsString(publicKey);

      _privateKeyPath = filePath;
      _privateKeyContent = privateKey;
      // _publicKeyContent = publicKey;
      // _publicKeyPath = '$filePath.pub';

      setState(() {});

      // Refresh available keys
      await _loadAvailableKeys();

      _showSuccess('SSH keys imported successfully!\nPrivate: $filePath');
      // Public: $filePath.pub');
    } catch (e) {
      _showError('Error importing keys: $e');
    }
  }

  Future<void> _selectKey(Map<String, String> keyInfo) async {
    try {
      final privateKeyFile = File(keyInfo['privatePath']!);
      final publicKeyFile = File(keyInfo['publicPath']!);

      if (await privateKeyFile.exists() && await publicKeyFile.exists()) {
        _privateKeyPath = privateKeyFile.path;
        _privateKeyContent = await privateKeyFile.readAsString();
        // _publicKeyContent = await publicKeyFile.readAsString();
        // _publicKeyPath = publicKeyFile.path;

        setState(() {});
        _showSuccess('Selected key: ${keyInfo['name']}');
      } else {
        _showError('Key files not found');
      }
    } catch (e) {
      _showError('Error selecting key: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Widget _buildKeyLocationItem(
  //     String title, String path, IconData icon, Color color) {
  //   return Container(
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: color.withValues(alpha: 0.1),
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: color.withValues(alpha: 0.3)),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(icon, color: color, size: 20),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 title,
  //                 style: TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   color: color,
  //                   fontSize: 14,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 path,
  //                 style: TextStyle(
  //                   color: Colors.grey.shade300,
  //                   fontSize: 12,
  //                   fontFamily: 'monospace',
  //                 ),
  //                 maxLines: 2,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ],
  //           ),
  //         ),
  //         IconButton(
  //           icon: Icon(Icons.copy, color: color, size: 18),
  //           onPressed: () async {
  //             await Clipboard.setData(ClipboardData(text: path));
  //             _showSuccess('Path copied to clipboard');
  //           },
  //           tooltip: 'Copy path',
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _connect() async {
    final List<String> missingFields = [];

    if (_ipController.text.isEmpty) {
      missingFields.add('IP Address');
    }
    if (_usernameController.text.isEmpty) {
      missingFields.add('Username');
    }
    if (_portController.text.isEmpty) {
      missingFields.add('Port');
    } else {
      final port = int.tryParse(_portController.text);
      if (port == null || port < 1 || port > 65535) {
        missingFields.add('Valid Port (1-65535)');
      }
    }
    if (_usePasswordAuth) {
      if (_passwordController.text.isEmpty) {
        missingFields.add('Password');
      }
    } else {
      if (_privateKeyContent == null) {
        missingFields.add('SSH Key');
      }
    }

    if (missingFields.isNotEmpty) {
      _showError('Please fill in: ${missingFields.join(', ')}');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final port = int.tryParse(_portController.text) ?? 22;

      final socket = await SSHSocket.connect(
        _ipController.text,
        port,
        timeout: const Duration(seconds: 30),
      ).catchError((error) {
        throw Exception(
            'Network error: $error\nPlease check your connection and firewall settings.');
      });

      if (_usePasswordAuth) {
        // Use password authentication
        _client = SSHClient(
          socket,
          username: _usernameController.text,
        );
        // For password auth, we'll need to handle it differently
        // This is a simplified implementation - in production you'd need proper password auth
      } else {
        // Use SSH key authentication
        _client = SSHClient(
          socket,
          username: _usernameController.text,
          identities: [
            // Use the private key for authentication
            ...SSHKeyPair.fromPem(_privateKeyContent!),
          ],
        );
      }

      await _client!.authenticated.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Authentication timeout'),
      );

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: 80,
          height: _terminal.viewHeight,
          // terminal: 'xterm-256color',
        ),
      );

      _session!.stdout.listen(
        (data) => _terminal.write(String.fromCharCodes(data)),
        onError: (error) => _showError('Output error: $error'),
      );

      _session!.stderr.listen(
        (data) => _terminal.write(String.fromCharCodes(data)),
        onError: (error) => _showError('Error output: $error'),
      );

      _terminal.onOutput = (data) {
        _session!.write(Uint8List.fromList(data.codeUnits));
      };

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      _showError('Connection error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SSH Terminal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: Colors.grey.shade900,
          elevation: 0,
          actions: [
            if (_isConnected) ...[
              // Stop Command button (Ctrl+C)
              IconButton(
                icon: const Icon(Icons.stop),
                tooltip: 'Stop Command (Ctrl+C)',
                onPressed: () {
                  // Send Ctrl+C signal (ASCII 3)
                  _session?.write(Uint8List.fromList([3]));
                },
              ),
              // Previous command button
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Previous Command',
                onPressed: () =>
                    _session?.write(Uint8List.fromList([27, 91, 65]))
                // _terminal.write('\x1B[A')
                ,
              ),
              // Next command button
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Next Command',
                onPressed: () =>
                    _session?.write(Uint8List.fromList([27, 91, 66]))
                // _terminal.write('\x1B[B')
                ,
              ),
              IconButton(
                icon: const Icon(Icons.cleaning_services),
                tooltip: 'Clear Terminal',
                onPressed: () {
                  // Clear terminal using ANSI escape sequence
                  _terminal.write('\x1B[2J\x1B[H');
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _terminal.write('\x1B[2J\x1B[H');
                  _session?.close();
                  _client?.close();
                  setState(() => _isConnected = false);
                },
              ),
            ]
          ],
        ),
        backgroundColor: Colors.grey.shade800,
        body: Column(
          children: [
            if (!_isConnected) ...[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Connection Form Section
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color:
                                  Colors.green.shade600.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.settings_ethernet,
                                    color: Colors.green.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Connection Details',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.green.shade300,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _ipController,
                                  decoration: const InputDecoration(
                                    labelText: 'IP Address',
                                    hintText: '1.1.1.1',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    hintText: 'ubuntu',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _portController,
                                  decoration: const InputDecoration(
                                    labelText: 'Port',
                                    hintText: '22',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),

                                // Authentication Method Toggle
                                Card(
                                  color: Colors.grey.shade800,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 12, bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Authentication Method',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: RadioListTile<bool>(
                                                title: const Text('SSH Key'),
                                                value: false,
                                                groupValue: _usePasswordAuth,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _usePasswordAuth = value!;
                                                    if (!_usePasswordAuth) {
                                                      _passwordController
                                                          .clear();
                                                    }
                                                  });
                                                },
                                                activeColor: Colors.blue,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                              ),
                                            ),
                                            Expanded(
                                              child: RadioListTile<bool>(
                                                title: const Text('Password'),
                                                value: true,
                                                groupValue: _usePasswordAuth,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _usePasswordAuth = value!;
                                                    if (_usePasswordAuth) {
                                                      _privateKeyPath = null;
                                                      _privateKeyContent = null;
                                                      // _publicKeyContent = null;
                                                      // _publicKeyPath = null;
                                                    }
                                                  });
                                                },
                                                activeColor: Colors.blue,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Password field (shown when password auth is selected)
                                if (_usePasswordAuth) ...[
                                  TextField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      hintText: 'Enter server password',
                                    ),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (!_usePasswordAuth)
                                  SizedBox(
                                    width: double
                                        .infinity, // ensures full-width like Expanded
                                    child: ElevatedButton.icon(
                                      onPressed: _importExistingKeys,
                                      icon: const Icon(Icons.file_upload),
                                      label: const Text('Import Private Key'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            _isConnecting ? null : _connect,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                        child: _isConnecting
                                            ? const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Connecting...'),
                                                ],
                                              )
                                            : const Text('Connect'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _saveCurrentProfile,
                                        icon: const Icon(Icons.save),
                                        label: const Text('Save Profile'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueGrey,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SSH Key Management Section (only show when not using password auth)
                    // if (!_usePasswordAuth) ...[
                    //   Card(
                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Container(
                    //           padding: const EdgeInsets.all(16.0),
                    //           decoration: BoxDecoration(
                    //             color:
                    //                 Colors.blue.shade600.withValues(alpha: 0.1),
                    //             borderRadius: const BorderRadius.only(
                    //               topLeft: Radius.circular(16),
                    //               topRight: Radius.circular(16),
                    //             ),
                    //           ),
                    //           child: Row(
                    //             children: [
                    //               Icon(Icons.vpn_key,
                    //                   color: Colors.blue.shade400),
                    //               const SizedBox(width: 8),
                    //               Text(
                    //                 'SSH Key Management',
                    //                 style: Theme.of(context)
                    //                     .textTheme
                    //                     .titleLarge
                    //                     ?.copyWith(
                    //                       color: Colors.blue.shade300,
                    //                       fontWeight: FontWeight.bold,
                    //                     ),
                    //               ),
                    //             ],
                    //           ),
                    //         ),
                    //         Padding(
                    //           padding: const EdgeInsets.all(16.0),
                    //           child: Column(
                    //             crossAxisAlignment: CrossAxisAlignment.start,
                    //             children: [
                    //               Row(
                    //                 children: [
                    //                   Expanded(
                    //                     child: ElevatedButton.icon(
                    //                       onPressed: _isConnecting
                    //                           ? null
                    //                           : _generateKeyPair,
                    //                       icon: _isConnecting
                    //                           ? const SizedBox(
                    //                               width: 16,
                    //                               height: 16,
                    //                               child:
                    //                                   CircularProgressIndicator(
                    //                                       strokeWidth: 2),
                    //                             )
                    //                           : const Icon(Icons.key),
                    //                       label: Text(_isConnecting
                    //                           ? 'Generating...'
                    //                           : 'Generate New Key'),
                    //                       style: ElevatedButton.styleFrom(
                    //                         backgroundColor:
                    //                             const Color.fromARGB(
                    //                                 255, 36, 170, 141),
                    //                         foregroundColor: Colors.white,
                    //                         padding: const EdgeInsets.symmetric(
                    //                             vertical: 12),
                    //                       ),
                    //                     ),
                    //                   ),
                    //                   const SizedBox(width: 8),
                    //                   Expanded(
                    //                     child: ElevatedButton.icon(
                    //                       onPressed: _importExistingKeys,
                    //                       icon: const Icon(Icons.file_upload),
                    //                       label: const Text('Import Keys'),
                    //                       style: ElevatedButton.styleFrom(
                    //                         backgroundColor:
                    //                             Colors.blue.shade600,
                    //                         foregroundColor: Colors.white,
                    //                         padding: const EdgeInsets.symmetric(
                    //                             vertical: 12),
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               if (_publicKeyContent != null) ...[
                    //                 const SizedBox(height: 8),
                    //                 ElevatedButton.icon(
                    //                   onPressed: _sharePublicKey,
                    //                   icon: const Icon(Icons.share),
                    //                   label: const Text('Share Public Key'),
                    //                   style: ElevatedButton.styleFrom(
                    //                     backgroundColor: Colors.green.shade600,
                    //                     foregroundColor: Colors.white,
                    //                   ),
                    //                 ),
                    //               ],
                    //             ],
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    //   const SizedBox(height: 16),
                    // ],

                    // Key Selection Section (only show when not using password auth)
                    if (!_usePasswordAuth) ...[
                      if (_availableKeys.isNotEmpty) ...[
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade600
                                      .withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.keyboard_arrow_down,
                                        color: Colors.indigo.shade400),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Select Key Pair',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.indigo.shade300,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(Icons.refresh,
                                          color: Colors.indigo.shade400),
                                      onPressed: _loadAvailableKeys,
                                      tooltip: 'Refresh keys',
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: _availableKeys.map((keyInfo) {
                                    final isSelected = _privateKeyPath ==
                                        keyInfo['privatePath'];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: Icon(
                                          keyInfo['type'] == 'Generated'
                                              ? Icons.vpn_key
                                              : Icons.file_upload,
                                          color: isSelected
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        title: Text(
                                          keyInfo['name']!,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.green
                                                : Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${keyInfo['type']} • ${keyInfo['timestamp']}',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.green.shade300
                                                : Colors.grey,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : Icon(Icons.radio_button_unchecked,
                                                color: Colors.grey),
                                        onTap: () => _selectKey(keyInfo),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: isSelected
                                                ? Colors.green
                                                : Colors.grey.shade600,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Key File Locations Section (only show when not using password auth)
                    // if (!_usePasswordAuth) ...[
                    //   if (_privateKeyPath != null ||
                    //       _publicKeyPath != null) ...[
                    //     Card(
                    //       child: Column(
                    //         crossAxisAlignment: CrossAxisAlignment.start,
                    //         children: [
                    //           Container(
                    //             padding: const EdgeInsets.all(16.0),
                    //             decoration: BoxDecoration(
                    //               color: Colors.orange.shade600
                    //                   .withValues(alpha: 0.1),
                    //               borderRadius: const BorderRadius.only(
                    //                 topLeft: Radius.circular(16),
                    //                 topRight: Radius.circular(16),
                    //               ),
                    //             ),
                    //             child: Row(
                    //               children: [
                    //                 Icon(Icons.folder_open,
                    //                     color: Colors.orange.shade400),
                    //                 const SizedBox(width: 8),
                    //                 Text(
                    //                   'Key File Locations',
                    //                   style: Theme.of(context)
                    //                       .textTheme
                    //                       .titleLarge
                    //                       ?.copyWith(
                    //                         color: Colors.orange.shade300,
                    //                         fontWeight: FontWeight.bold,
                    //                       ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //           Padding(
                    //             padding: const EdgeInsets.all(16.0),
                    //             child: Column(
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: [
                    //                 if (_privateKeyPath != null) ...[
                    //                   _buildKeyLocationItem(
                    //                     'Private Key',
                    //                     _privateKeyPath!,
                    //                     Icons.vpn_key,
                    //                     Colors.red,
                    //                   ),
                    //                   const SizedBox(height: 12),
                    //                 ],
                    //                 if (_publicKeyPath != null) ...[
                    //                   _buildKeyLocationItem(
                    //                     'Public Key',
                    //                     _publicKeyPath!,
                    //                     Icons.public,
                    //                     Colors.blue,
                    //                   ),
                    //                 ],
                    //               ],
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //     const SizedBox(height: 16),
                    //   ],
                    // ],

                    // Saved Profiles Section
                    // if (_savedProfiles.isNotEmpty)
                    ...[
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade600
                                    .withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.history,
                                      color: Colors.purple.shade400),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Saved Connections',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.purple.shade300,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (_savedProfiles.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _savedProfiles.length,
                                itemBuilder: (context, index) {
                                  final profile = _savedProfiles[index];
                                  return ListTile(
                                    title: Text(profile.name),
                                    subtitle: Text(
                                        '${profile.username}@${profile.host}:${profile.port}\n${profile.usePasswordAuth ? 'Password Auth' : 'SSH Key Auth'}'),
                                    leading: Icon(
                                      profile.usePasswordAuth
                                          ? Icons.lock
                                          : Icons.vpn_key,
                                      color: profile.usePasswordAuth
                                          ? Colors.orange
                                          : Colors.blue,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _deleteProfile(profile),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.play_arrow),
                                          onPressed: () async {
                                            _loadProfile(profile);
                                            await Future.delayed(
                                                const Duration(seconds: 1));
                                            _connect();
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () => _loadProfile(profile),
                                  );
                                },
                              ),
                            if (_savedProfiles.isEmpty)
                              Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        Colors.grey.shade600.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cloud_off_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Saved Connections',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Colors.grey.shade300,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Save your SSH connections for quick access.\nCreate a new connection to get started.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey.shade400,
                                            height: 1.4,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Container(
                                    //   padding: const EdgeInsets.symmetric(
                                    //     horizontal: 12,
                                    //     vertical: 8,
                                    //   ),
                                    //   decoration: BoxDecoration(
                                    //     color: Colors.blue.shade900
                                    //         .withOpacity(0.3),
                                    //     borderRadius: BorderRadius.circular(8),
                                    //     border: Border.all(
                                    //       color: Colors.blue.shade700
                                    //           .withOpacity(0.5),
                                    //       width: 1,
                                    //     ),
                                    //   ),
                                    //   child: Row(
                                    //     mainAxisSize: MainAxisSize.min,
                                    //     children: [
                                    //       Icon(
                                    //         Icons.info_outline,
                                    //         size: 16,
                                    //         color: Colors.blue.shade300,
                                    //       ),
                                    //       const SizedBox(width: 8),
                                    //       Text(
                                    //         'Tip: Use the form above to create your first connection',
                                    //         style: Theme.of(context)
                                    //             .textTheme
                                    //             .bodySmall
                                    //             ?.copyWith(
                                    //               color: Colors.blue.shade200,
                                    //               fontSize: 12,
                                    //             ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_isConnected)
              Expanded(
                child: Stack(
                  children: [
                    TerminalView(
                      _terminal,
                      // terminal: _terminal,
                      // style: const TerminalStyle(
                      //   fontSize: 14,
                      //   fontFamily: 'Courier',
                      // ),
                    ),
                    // Floating action buttons for terminal shortcuts
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ctrl+D button
                          FloatingActionButton(
                            mini: true,
                            heroTag: "ctrl_d",
                            onPressed: () {
                              // Send Ctrl+D signal (ASCII 4)
                              _session?.write(Uint8List.fromList([4]));
                            },
                            tooltip: 'Ctrl+D (EOF)',
                            child: const Text('D',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          // Ctrl+Z button
                          FloatingActionButton(
                            mini: true,
                            heroTag: "ctrl_z",
                            onPressed: () {
                              // Send Ctrl+Z signal (ASCII 26)
                              _session?.write(Uint8List.fromList([26]));
                            },
                            tooltip: 'Ctrl+Z (Suspend)',
                            child: const Text('Z',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          // Ctrl+C button (Stop Command)
                          FloatingActionButton(
                            mini: true,
                            heroTag: "ctrl_c",
                            onPressed: () {
                              // Send Ctrl+C signal (ASCII 3)
                              _session?.write(Uint8List.fromList([3]));
                            },
                            tooltip: 'Ctrl+C (Stop Command)',
                            backgroundColor: Colors.red.shade600,
                            child: const Icon(Icons.stop, size: 16),
                          ),
                        ],
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
}
