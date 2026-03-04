# StartIt 🚀

<p align="center">
  <img src="https://github.com/prathyushnallamothu/startit/raw/master/logo.png" alt="StartIt Logo" width="200"/>
</p>

<p align="center">
  <b>AI-Powered Repository Setup Assistant</b><br/>
  Automate GitHub repository setup with intelligent command execution and real-time terminal output
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#development">Development</a> •
  <a href="#troubleshooting">Troubleshooting</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## Overview

StartIt revolutionizes the way developers interact with new GitHub repositories by automating the tedious setup process. Instead of manually reading through READMEs and executing setup commands one by one, StartIt analyzes repositories, identifies setup instructions, and executes them with proper error handling - all through an intuitive GUI.

**Say goodbye to setup frustration and get coding faster!**

## Features

### 🔍 Intelligent Repository Analysis
- Automatically detects setup instructions from README files and common setup scripts
- Identifies project dependencies and prerequisites
- Supports multiple programming languages and frameworks

### 🛠️ Command Execution System
- Executes commands safely with proper error handling
- Real-time terminal output with color coding
- Background command execution with status tracking
- Command queueing for sequential execution

### 🌳 Git Integration
- Clone any public GitHub repository
- Branch selection for repository-specific setup

### 🤖 AI-Powered Features
- Smart parsing of repository documentation
- Automated identification of setup steps

### 💻 Modern User Interface
- Clean, intuitive Flutter-based UI
- Real-time terminal output window
- Setup step tracking and visualization
- Prerequisite detection and installation

### 🌐 Cross-Platform Support
- Works on macOS, Windows, and Linux
- Consistent experience across operating systems

## Installation

### Prerequisites
- Git installed and configured
- Internet connection for repository cloning and AI features


## Usage

### Quick Start

1. Launch StartIt application
2. Enter a GitHub repository URL in the input field
3. Click "Analyze Repository"
4. Review the detected setup steps and prerequisites
5. Click "Run Setup Commands" to execute all steps
6. Monitor the terminal output for progress and results

### Advanced Options

- **Branch Selection**: Specify which branch to clone and analyze
- **Manual Command Execution**: Run individual commands instead of the entire sequence
- **Prerequisite Installation**: Install detected project prerequisites
- **Troubleshooting**: Get AI assistance with failed commands

## Architecture

StartIt is built with a clear separation of concerns:

### Backend (Go)

```
/backend
├── cmd/                 # Application entry points
│   └── server/          # API server
├── internal/            # Private application code
│   ├── api/             # REST API handlers and routers
│   ├── executor/        # Command execution system
│   │   ├── command.go   # Command handling
│   │   └── background.go # Background commands
│   ├── git/             # Git operations
│   ├── ai/              # OpenAI integration
│   └── analyzer/        # Repository analysis
└── go.mod              # Go module file
```

The backend provides:
- REST API for frontend communication
- Repository cloning and analysis
- Command execution in isolated environments
- Real-time command output streaming
- AI-based troubleshooting

### Frontend (Flutter)

```
/frontend
├── lib/                 # Source code
│   ├── models/          # Data models
│   ├── screens/         # UI screens
│   │   ├── home_screen.dart    # Main screen
│   │   └── analysis_screen.dart # Repository analysis
│   ├── services/        # Business logic
│   │   ├── api_service.dart     # API communication
│   │   ├── command_service.dart # Command handling
│   │   └── repository_provider.dart # State management
│   └── widgets/         # Reusable UI components
│       ├── terminal_output.dart # Terminal UI
│       ├── prerequisites_widget.dart # Prerequisites UI
│       └── setup_steps.dart     # Setup steps UI
└── pubspec.yaml        # Flutter dependencies
```

The frontend provides:
- Intuitive user interface
- Real-time terminal display
- Repository analysis visualization
- Command execution controls
- State management via Provider

## Development

### Prerequisites

- Go 1.18+ for backend development
- Flutter 3.0+ for frontend development
- Git
- OpenAI API Key (for AI features)

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Copy environment variables example and configure:
   ```bash
   cp .env.example .env
   # Edit .env and add OPENAI_API_KEY
   ```

3. Install dependencies:
   ```bash
   go mod tidy
   ```

4. Run the server:
   ```bash
   go run cmd/server/main.go
   ```

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   # For desktop
   flutter run -d macos  # or windows/linux
   
   # For web (development only)
   flutter run -d chrome
   ```

## API Reference

StartIt's backend exposes a RESTful API:

### Repository Operations

- `POST /api/repositories/clone`
  - Clone a repository
  - Body: `{"url": "https://github.com/user/repo", "branch": "main"}`

- `POST /api/repositories/analyze`
  - Analyze a cloned repository
  - Body: `{"path": "/path/to/repo"}`

### Command Operations

- `POST /api/commands/execute`
  - Execute a command
  - Body: `{"command": "npm install", "directory": "/path/to/repo"}`

- `POST /api/commands/background`
  - Execute a command in the background
  - Body: `{"command": "npm install", "directory": "/path/to/repo"}`

- `GET /api/commands/status/:commandId`
  - Get status of a background command

### Troubleshooting

- `POST /api/troubleshoot`
  - Get AI help for a failed command
  - Body: `{"error": "error message", "repoPath": "/path/to/repo", "context": "additional context"}`

## Troubleshooting

### Common Issues

#### Repository Cloning Fails
- Ensure the repository URL is correct
- Check your internet connection
- Verify Git is properly installed and configured
- For private repositories, ensure your Git credentials are set up

#### Command Execution Errors
- Check terminal output for specific error messages
- Ensure prerequisites are installed
- Verify you have the necessary permissions

#### Missing Prerequisites
- Use the prerequisites widget to install missing dependencies
- Some prerequisites may need manual installation outside StartIt

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

[Prathyush Nallamothu](https://github.com/prathyushnallamothu)

---

<p align="center">
  Made with ❤️ by Prathyush Nallamothu
</p>
