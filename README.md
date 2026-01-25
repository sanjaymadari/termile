# Termile

A modern SSH terminal emulator built with Flutter for mobile devices. Termile provides a full-featured terminal experience with SSH connectivity, connection profile management, SSH key support, and **Termux-inspired features**.

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

### 📑 Multi-Session Tabs (NEW!)

- **Browser-style Tabs**: Open multiple SSH sessions simultaneously
- **Visual Status Indicators**: See connection status at a glance (green = connected, yellow = connecting, grey = disconnected)
- **Quick Tab Management**: Add, switch, and close sessions with ease
- **Session Persistence**: Each tab maintains its own terminal state

### ⌨️ Termux-Style Extra Keys (NEW!)

- **Special Keys Row**: ESC, CTRL, ALT, TAB buttons always accessible
- **Arrow Keys**: Navigate command history and text with dedicated buttons
- **Quick Symbols**: Common terminal characters (|, /, ~, -, _, {, }, [, ], $)
- **Haptic Feedback**: Optional vibration on key press

### 📋 Copy & Paste Support (NEW!)

- **Long-press Context Menu**: Access copy, paste, and clear options
- **Clipboard Integration**: Seamlessly copy from and paste to terminal
- **Selection Support**: Select and copy terminal output

### 🔤 Font Size Control (NEW!)

- **Quick Size Buttons**: Increase/decrease font size from the app bar
- **Settings Slider**: Fine-grained control with visual slider
- **Persistent Settings**: Font size preference saved across sessions
- **Range**: 8px to 32px with 14px default

### 🎨 Color Themes (NEW!)

Choose from 8 beautiful pre-built terminal themes:
- **Default Dark** - Classic dark terminal
- **Dracula** - Popular dark purple theme
- **Solarized Dark** - Eye-friendly color scheme
- **Monokai** - Sublime Text inspired
- **Nord** - Arctic, bluish colors
- **One Dark** - Atom editor theme
- **Gruvbox Dark** - Retro groove colors
- **Tokyo Night** - Modern Japanese-inspired

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

   - Tap "Import SSH Key" to import your existing SSH private key
   - Or use password authentication for simpler setup

2. **Create Connection Profile**:

   - Enter server details (IP/hostname, username, port)
   - Select authentication method (key or password)
   - Save the profile for future use

3. **Connect**:
   - Select a saved profile or enter connection details manually
   - Tap "Connect" to establish SSH connection

### Managing Sessions

- **New Tab**: Tap the + button to create a new session
- **Switch Tabs**: Tap on any tab to switch to that session
- **Close Tab**: Tap the X on a tab to close the session
- **Status Colors**: Green (connected), Yellow (connecting), Grey (disconnected)

### Using Extra Keys

- **ESC**: Send escape character
- **CTRL**: Modifier for control combinations
- **ALT**: Modifier for alt combinations
- **TAB**: Auto-complete commands
- **Arrows**: Navigate command history and move cursor
- **Quick Symbols**: Type common terminal characters easily

### Customizing Terminal

1. Open Settings (gear icon in app bar)
2. **Font Size**: Use slider or +/- buttons to adjust
3. **Theme**: Tap on any theme card to apply
4. **Options**: Toggle extra keys, haptic feedback, and bell sound

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
- **Copy/Paste**: Long-press for context menu
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

- **v1.0.7+7**: Initiated Phase 3: Productivity & Platform:
  - Command Snippet Manager: Save and execute frequently used commands with one tap
  - Terminal Search (Find): Powerful buffer search with real-time highlighting and navigation
  - **Local Terminal Support**: Run local shell sessions without SSH on macOS, Linux, Windows, and Android
  - Snippet UI: High-quality picker sheet with add/edit/delete capabilities
  - Auto-execution: Support for automatically sending Enter after a snippet command
- **v1.0.6+6**: Added Phase 2: File & Transfer Features:
  - SFTP File Browser: Full remote file management
  - File Upload/Download: Seamless file transfers between local and remote
  - Text File Viewer/Editor: Quick edits on remote files
  - SSH Key Selection: New visual dropdown for managing available keys
  - Customizable Extra Keys: Add and remove keys in the extra row
- **v1.0.5+5**: Added Phase 1: Core Terminal Enhancements:
  - Multi-session tabs
  - Extra keys row (ESC, CTRL, ALT, TAB, arrows)
  - Copy/paste support with context menu
  - Font size control
  - 8 beautiful color themes
  - Settings dialog with live preview
- **v1.0.3+4**: SSH key management and connection profiles
- **v1.0.0+1**: Initial release with basic SSH terminal functionality

## Support

For issues, feature requests, or questions:

- Open an issue on GitHub
- Check the documentation
- Review the code comments for implementation details

---
