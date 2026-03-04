# Sensei AI



<p align="center">
  <b>Intelligent Repository Setup & Automation Engine</b><br/>
  Automate GitHub repository initialization with AI-driven command parsing, safe execution, and real-time terminal feedback.
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#api-reference">API Reference</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## Overview

Sensei AI revolutionizes developer onboarding by automating the repository setup process. Instead of manually parsing `README` files and executing configuration commands sequentially, Sensei AI leverages artificial intelligence to analyze project documentation, identify necessary prerequisites, and safely execute setup instructions through an intuitive graphical interface.

Minimize configuration drift, eliminate setup friction, and accelerate your time-to-code.

## Features

### 🔍 Intelligent Repository Analysis
- Automatically parses and extracts setup instructions from documentation and initialization scripts.
- Accurately identifies project dependencies and system prerequisites.
- Seamlessly supports multiple programming languages and development frameworks.

### 🛠️ Robust Execution Engine
- Safely executes commands within isolated environments with comprehensive error handling.
- Provides real-time, color-coded terminal output for complete visibility.
- Supports background command execution with granular status tracking and sequential queueing.

### 🌳 Git Integration
- Natively clones public GitHub repositories.
- Supports specific branch targeting for precise repository environment setup.

### 🤖 AI-Powered Troubleshooting
- **Smart Documentation Parsing:** Deep semantic analysis of repository documentation.
- **Automated Issue Resolution:** Context-aware troubleshooting recommendations for failed commands and dependency conflicts.

### 💻 Modern User Interface
- High-performance, cross-platform UI built with Flutter.
- Integrated real-time terminal emulator.
- Visual step-tracking and prerequisite validation workflows.



## Installation

### System Prerequisites
- **Git** installed and configured in your system path.
- Active internet connection.
- Valid API key for AI features (e.g., OpenAI API).

### Quick Start
1. Clone the repository and navigate to the backend directory to set up the Go server.
2. Provide your AI configuration in the `.env` file.
3. Navigate to the frontend directory and run `flutter pub get` followed by `flutter run`.

## Usage

1. Launch the **Sensei AI** application.
2. Input the target GitHub repository URL.
3. Click **Analyze Repository** to initiate the AI parsing engine.
4. Review the extracted setup workflow and required dependencies.
5. Click **Run Setup Commands** to begin the automated initialization.
6. Monitor the integrated terminal for real-time progress. Utilize the **AI Troubleshoot** feature if execution errors occur.







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

Sensei AI utilizes a decoupled architecture for maximum performance and scalability:

### Backend (Go)
- **API Server:** Exposes a robust RESTful API for client communication.
- **Execution Environment:** Manages secure command execution and output streaming.
- **AI Analyzer:** Integrates with LLMs to process natural language documentation and provide error resolution.


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
- **Dashboard Interface:** Centralized hub for repository analysis and management.
- **Terminal Component:** Real-time log streaming and execution visualization.
- **State Management:** Efficient UI state handling for a seamless user experience.

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


