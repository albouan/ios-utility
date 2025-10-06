## DocumentsViewController

A lightweight iOS file browser for your app's Documents directory with import/export capabilities and basic file operations.

### Features
- Browse and manage files in your app's Documents folder
- Import/export files and folders with progress tracking and cancellation
- Security-scoped resource handling for external files
- Basic file operations (rename, delete, export)
- Thread-safe implementation with proper iOS compatibility

### Quick usage
- Present the controller:
  - [DocumentsViewController launchFrom:presenterViewController];
- The controller provides UI buttons to "Copy File to App Documents" and "Copy Folder to App Documents".
- Item actions: Export (copy out), Rename, Delete.

### Author
[GitHub Copilot](https://github.com/features/copilot) for @albouan
