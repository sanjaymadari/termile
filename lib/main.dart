import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:termile/connection_profile.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _profileNameController = TextEditingController();
  final _terminal = Terminal();
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _privateKeyPath;
  String? _privateKeyContent;
  String? _publicKeyContent;
  List<ConnectionProfile> _savedProfiles = [];

  @override
  void initState() {
    super.initState();
    _checkExistingKeys();
    _loadSavedProfiles();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _portController.dispose();
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
    if (_ipController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _privateKeyPath == null) {
      _showError('Please fill in all connection details first');
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
                keyPath: _privateKeyPath!,
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
      _privateKeyPath = profile.keyPath;
    });
    // Load the key content
    if (profile.keyPath.isNotEmpty) {
      File(profile.keyPath).readAsString().then((content) {
        _privateKeyContent = content;
      }).catchError((error) {
        _showError('Error loading key: $error');
      });
    }
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
      final privateKeyFile = File('${directory.path}/id_rsa');
      final publicKeyFile = File('${directory.path}/id_rsa.pub');

      if (await privateKeyFile.exists() && await publicKeyFile.exists()) {
        _privateKeyPath = privateKeyFile.path;
        _privateKeyContent = await privateKeyFile.readAsString();
        _publicKeyContent = await publicKeyFile.readAsString();
        setState(() {});
      }
    } catch (e) {
      _showError('Error checking existing keys: $e');
    }
  }

  // Future<void> _generateKeyPair() async {
  //   try {
  //     setState(() => _isConnecting = true);

  //     // Generate RSA key pair
  //     final keyPair = await SSHKeyPair.generate(
  //       type: SSHKeyPairType.rsa,
  //       comment: 'generated by flutter ssh app',
  //     );

  //     final directory = await getApplicationDocumentsDirectory();

  //     // Save private key
  //     final privateKeyFile = File('${directory.path}/id_rsa');
  //     await privateKeyFile.writeAsString(keyPair.privateKey);
  //     _privateKeyPath = privateKeyFile.path;
  //     _privateKeyContent = keyPair.privateKey;

  //     // Save public key
  //     final publicKeyFile = File('${directory.path}/id_rsa.pub');
  //     await publicKeyFile.writeAsString(keyPair.publicKey);
  //     _publicKeyContent = keyPair.publicKey;

  //     setState(() => _isConnecting = false);

  //     if (!mounted) return;
  //     _showSuccess('SSH key pair generated successfully!');
  //   } catch (e) {
  //     setState(() => _isConnecting = false);
  //     _showError('Error generating key pair: $e');
  //   }
  // }

  Future<void> _sharePublicKey() async {
    if (_publicKeyContent == null) {
      _showError('No public key available');
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final tempFile = File('${directory.path}/id_rsa.pub');
      await tempFile.writeAsString(_publicKeyContent!);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'My SSH public key',
      );
    } catch (e) {
      _showError('Error sharing public key: $e');
    }
  }

  Future<void> _importExistingKeys() async {
    try {
      // Pick private key
      final privateResult = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select private key (id_rsa)',
      );
      if (privateResult == null) return;

      // Pick public key
      final publicResult = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select public key (id_rsa.pub)',
      );
      if (publicResult == null) return;

      // Read and validate keys
      final privateKey =
          await File(privateResult.files.single.path!).readAsString();
      final publicKey =
          await File(publicResult.files.single.path!).readAsString();

      // Save keys to app directory
      final directory = await getApplicationDocumentsDirectory();
      await File('${directory.path}/id_rsa').writeAsString(privateKey);
      await File('${directory.path}/id_rsa.pub').writeAsString(publicKey);

      _privateKeyPath = '${directory.path}/id_rsa';
      _privateKeyContent = privateKey;
      _publicKeyContent = publicKey;

      setState(() {});
      _showSuccess('SSH keys imported successfully!');
    } catch (e) {
      _showError('Error importing keys: $e');
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

  Future<void> _connect() async {
    if (_privateKeyContent == null) {
      _showError('No SSH key available. Please generate or import keys first.');
      return;
    }

    if (_ipController.text.isEmpty || _usernameController.text.isEmpty) {
      _showError('Please fill in all fields');
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

      _client = SSHClient(
        socket,
        username: _usernameController.text,
        identities: [
          // Use the private key for authentication
          ...SSHKeyPair.fromPem(_privateKeyContent!),
        ],
      );

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Terminal'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _session?.close();
                _client?.close();
                setState(() => _isConnected = false);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected) ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Saved Profiles Section
                  if (_savedProfiles.isNotEmpty) ...[
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Saved Connections',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _savedProfiles.length,
                            itemBuilder: (context, index) {
                              final profile = _savedProfiles[index];
                              return ListTile(
                                title: Text(profile.name),
                                subtitle: Text(
                                    '${profile.username}@${profile.host}:${profile.port}'),
                                leading: const Icon(Icons.computer),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteProfile(profile),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow),
                                      onPressed: () {
                                        _loadProfile(profile);
                                        _connect();
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _loadProfile(profile),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // SSH Key Management Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SSH Key Management',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => {}, //_generateKeyPair,
                                  icon: const Icon(Icons.key),
                                  label: const Text('Generate New Keys'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _importExistingKeys,
                                  icon: const Icon(Icons.file_upload),
                                  label: const Text('Import Keys'),
                                ),
                              ),
                            ],
                          ),
                          if (_publicKeyContent != null) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _sharePublicKey,
                              icon: const Icon(Icons.share),
                              label: const Text('Share Public Key'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Connection Form Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connection Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'IP Address',
                              hintText: '1.1.1.1',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'ubuntu',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '22',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isConnecting ? null : _connect,
                                  child: _isConnecting
                                      ? const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Connecting...'),
                                          ],
                                        )
                                      : const Text('Connect'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _saveCurrentProfile,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Profile'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isConnected)
            Expanded(
              child: TerminalView(
                _terminal,
                // terminal: _terminal,
                // style: const TerminalStyle(
                //   fontSize: 14,
                //   fontFamily: 'Courier',
                // ),
              ),
            ),
        ],
      ),
    );
  }
}
