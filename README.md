# Termile

A modern SSH terminal emulator built with Flutter for mobile devices. Termile provides a full-featured terminal experience with SSH connectivity, connection profile management, and SSH key support.

## Features

### 🔐 SSH Connectivity

- **SSH Key Authentication**: Import and manage SSH key pairs for secure connections
- **Password Authentication**: Support for password-based SSH connections
- **Connection Profiles**: Save and manage multiple SSH connection configurations
- **Custom Ports**: Connect to SSH servers on any port (default: 22)

### 💻 Terminal Features

- **Full Terminal Emulation**: Complete xterm-compatible terminal experience
- **Keyboard Shortcuts**:
  - `Escape` key sends Ctrl+C to interrupt running commands
  - Command history navigation with arrow keys
- **Terminal Controls**:
  - Clear terminal screen
  - Stop running commands (Ctrl+C)
  - Navigate command history (up/down arrows)
  - Disconnect from SSH session

### 🔑 SSH Key Management

- **Import Existing Keys**: Import your existing SSH private keys
- **Key Validation**: Automatic validation of SSH key formats
- **Key Storage**: Secure local storage of imported SSH keys
- **Key Selection**: Easy switching between multiple SSH keys

### 📱 Mobile-Optimized UI

- **Dark Theme**: Modern dark theme optimized for mobile use
- **Responsive Design**: Adaptive layout for different screen sizes
- **Touch-Friendly**: Large buttons and intuitive touch controls
- **Material Design**: Follows Material Design principles

## Usage

### First Time Setup

1. **Import SSH Keys**:

   - Tap "Import Keys" to import your existing SSH private key
   - Or use password authentication for simpler setup

2. **Create Connection Profile**:

   - Enter server details (IP/hostname, username, port)
   - Select authentication method (key or password)
   - Save the profile for future use

3. **Connect**:
   - Select a saved profile or enter connection details manually
   - Tap "Connect" to establish SSH connection

### Managing Connections

- **Save Profiles**: Create named profiles for frequently accessed servers
- **Load Profiles**: Quickly load saved connection settings
- **Delete Profiles**: Remove unused connection profiles
- **Switch Keys**: Change SSH keys for different servers

### Terminal Usage

- **Type Commands**: Use the on-screen keyboard or external keyboard
- **Navigate History**: Use arrow keys or on-screen buttons to navigate command history
- **Interrupt Commands**: Press Escape or the stop button to send Ctrl+C
- **Clear Screen**: Use the clear button to clear the terminal
- **Disconnect**: Use the disconnect button to close the SSH session

## Dependencies

- **dartssh2**: SSH client implementation
- **xterm**: Terminal emulator widget
- **file_picker**: File selection for SSH key import
- **path_provider**: Local file system access
- **shared_preferences**: Settings and profile storage
- **share_plus**: Key sharing functionality

## Security Notes

- SSH keys are stored locally on your device
- Passwords are stored in plain text (consider using key-based authentication for better security)
- All connections use standard SSH protocols
- No data is transmitted to external servers

## Version History

- **v1.0.3+4**: Current version with SSH key management and connection profiles
- **v1.0.0+1**: Initial release with basic SSH terminal functionality

## Support

For issues, feature requests, or questions:

- Open an issue on GitHub
- Check the documentation
- Review the code comments for implementation details

---
