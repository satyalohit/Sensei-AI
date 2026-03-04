# StartIt Backend

The Golang backend for StartIt, providing APIs for repository management, LLM integration, and command execution.

## Structure

- `/cmd` - Main application entrypoints
- `/internal` - Private application and library code
  - `/api` - API handlers and routes
  - `/git` - Git repository operations
  - `/llm` - OpenAI API integration
  - `/executor` - Terminal command execution
- `/pkg` - Library code that's ok to use by external applications

## Setup

### Prerequisites
- Go 1.18+
- OpenAI API key

### Getting Started

1. Install dependencies:
   ```bash
   go mod tidy
   ```

2. Create a `.env` file with:
   ```
   OPENAI_API_KEY=your_api_key_here
   ```

3. Run the server:
   ```bash
   go run cmd/server/main.go
   ```

## API Endpoints

The backend provides the following API endpoints:

- `POST /api/repository/clone` - Clone a GitHub repository
- `POST /api/repository/analyze` - Analyze repository and extract setup instructions
- `POST /api/execute` - Execute a terminal command
- `POST /api/troubleshoot` - Get troubleshooting assistance for errors

Detailed API documentation will be added soon.
