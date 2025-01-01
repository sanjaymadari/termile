import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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
  final _terminal = Terminal();
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;
  String? _privateKeyPath;
  String? _privateKeyContent;

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _session?.close();
    _client?.close();
    super.dispose();
  }

  Future<void> _pickPrivateKey() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        _privateKeyPath = result.files.single.path!;
        // Read the private key content
        final file = File(_privateKeyPath!);
        _privateKeyContent = await file.readAsString();
        setState(() {}); // Update UI to show selected file
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _connect() async {
    if (_privateKeyContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a private key file')),
      );
      return;
    }

    try {
      setState(() => _isConnected = false);

      final socket = await SSHSocket.connect(
        _ipController.text,
        22, // Default SSH port
        timeout: const Duration(seconds: 10),
      );

      _client = SSHClient(
        socket,
        username: _usernameController.text,
        identities: [
          // Use the private key for authentication
          ...SSHKeyPair.fromPem(_privateKeyContent!),
        ],
      );

      final size = _terminal.viewHeight;
      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: 80,
          height: size,
          // terminal: 'xterm-256color',
        ),
      );

      _session!.stdout.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      _session!.stderr.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      _terminal.onOutput = (data) {
        _session!.write(Uint8List.fromList(data.codeUnits));
      };

      setState(() => _isConnected = true);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSH Terminal')),
      body: Column(
        children: [
          if (!_isConnected) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '1.1.1.1',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'ubuntu',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickPrivateKey,
                    icon: const Icon(Icons.key),
                    label: Text(_privateKeyPath != null
                        ? 'Selected: ${_privateKeyPath!.split('/').last}'
                        : 'Select Private Key'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _connect,
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          ],
          if (_isConnected)
            Expanded(
              child: TerminalView(
                _terminal,
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
