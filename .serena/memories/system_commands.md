# AwaitlessKit macOS Development Environment

## System Commands (macOS/Darwin)

### File Operations
- `ls` - List directory contents
- `find` - Search for files and directories
- `grep` - Search text patterns in files
- `cd` - Change directory
- `pwd` - Print working directory
- `mkdir` - Create directories
- `rm` - Remove files/directories
- `cp` - Copy files
- `mv` - Move/rename files

### Development Tools
- `git` - Version control (standard Git commands)
- `xcode-select` - Manage Xcode installations
- `xcodes` - Xcode version management (if installed)
- `pkill` - Kill processes by name (used for killing Xcode)

### Swift-specific Commands
- `swift --version` - Check Swift version
- `swift build` - Build Swift package
- `swift test` - Run Swift tests
- `swift package` - Package management commands

### Process Management
- `ps` - List running processes
- `kill` - Terminate processes
- `pkill -9 Xcode` - Force quit Xcode (used in Justfile)

### File Viewing/Editing
- `cat` - Display file contents
- `less` / `more` - Page through files
- `head` - Show first lines of file
- `tail` - Show last lines of file

### Archive/Compression
- `tar` - Archive files
- `zip` / `unzip` - Compression utilities

## macOS-specific Notes
- Commands are standard Unix/BSD variants
- Case-sensitive filesystem considerations
- Xcode integration is a key part of the workflow
- Uses `.DS_Store` files (should be gitignored)

## Productivity Tools Integration
- **Just** - Command runner (alternative to Make)
- **xcbeautify/xcpretty** - Xcode output formatting
- **SwiftFormat** - Code formatting
- **GitHub Actions** - CI/CD integration