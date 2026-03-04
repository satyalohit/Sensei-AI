# StartIt Frontend

A Flutter desktop application that provides a user-friendly interface for automating GitHub repository setup.

## Features

- Repository selection and cloning
- Visualization of setup instructions extracted by the AI
- Form interfaces for collecting environment variables and user inputs
- Real-time logs of command execution
- Troubleshooting assistance for errors

## Structure

- `/lib` - Application code
  - `/models` - Data models
  - `/screens` - UI screens
  - `/services` - API services and backend communication
  - `/utils` - Utility functions
  - `/widgets` - Reusable UI components

## Setup

### Prerequisites
- Flutter 3.0+
- StartIt backend running

### Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run -d macos # or windows/linux
   ```

## Building for Distribution

To build a standalone desktop application:

```bash
flutter build macos # or windows/linux
```

This will create a distributable package in the `build` directory.
