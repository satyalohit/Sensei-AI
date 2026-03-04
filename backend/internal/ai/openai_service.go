package ai

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
	"github.com/prathyushnallamothu/startit/backend/internal/git"
)

// OpenAIService handles interactions with the OpenAI API
type OpenAIService struct {
	client *openai.Client
	model  string
}

// NewOpenAIService creates a new OpenAI service with the API key from environment
func NewOpenAIService() (*OpenAIService, error) {
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		return nil, errors.New("OPENAI_API_KEY environment variable is not set")
	}

	// Create the OpenAI client
	client := openai.NewClient(
		option.WithAPIKey(apiKey),
	)

	return &OpenAIService{
		client: client,
		model:  string(openai.ChatModelGPT4oMini), // Use GPT-4 as string
	}, nil
}

// AnalyzeRepository analyzes a Git repository using OpenAI
func (s *OpenAIService) AnalyzeRepository(ctx context.Context, repo *git.Repository) (RepositoryAnalysis, error) {
	// Get repository markdown files
	readmeContent, err := getRepositoryReadmeContent(repo.LocalDir)
	if err != nil {
		log.Printf("Error reading repository README: %v", err)
	}

	// Get Makefile content if available
	makefileContent, err := getMakefileContent(repo.LocalDir)
	if err != nil {
		log.Printf("Makefile not found or couldn't be read: %v", err)
		// Continue without Makefile content
		makefileContent = "No Makefile found"
	}

	// Get directory structure to provide context about where to run commands
	dirStructure, err := getDirectoryStructure(repo.LocalDir, 3) // Limit to 3 levels deep to avoid excessive output
	if err != nil {
		log.Printf("Error generating directory structure: %v", err)
		// Continue without the directory structure if there's an error
		dirStructure = "Unable to generate directory structure"
	}

	// Construct the repository info string
	repoInfo := fmt.Sprintf("Repository name: %s, Repository URL: %s", filepath.Base(repo.LocalDir), repo.URL)

	// Construct the prompt
	prompt := fmt.Sprintf(`Analyze the following repository and provide the following information in JSON format:

{
  "description": "A concise description of what this repository/project is",
  "prerequisites": [
    {
      "name": "Name of prerequisite/dependency",
      "description": "Brief description of why it's needed", 
      "installCommand": "Command to install this prerequisite"
    }
  ],
  "commands": [
    "Command 1 to run",
    "Command 2 to run"
  ]
}

Instructions:
- ONLY return the clean JSON object with no additional text.
- For commands, provide ONLY executable commands that can be directly copied into a terminal without any formatting.
- For prerequisites, include common software, tools, or dependencies required for this project.
- Only provide the information that are defined in the repository markdown files DO NOT MAKE UP ANYTHING.
- Imagine you are running the project locally so provide commands that you would run to execute the commands.
- Look at the directory structure below to determine the appropriate directories where commands should be run.
- Use the Makefile targets if a Makefile is present to determine the correct build/run commands.

Repository Information:
%s

Directory Structure:
%s

Repository README content:
%s

Makefile content:
%s`, repoInfo, dirStructure, readmeContent, makefileContent)

	// Call OpenAI API to analyze the repository
	content, err := s.callOpenAI(ctx, prompt)
	if err != nil {
		return RepositoryAnalysis{}, fmt.Errorf("failed to call OpenAI: %w", err)
	}

	// Parse the response into structured data
	var jsonResponse struct {
		Description   string        `json:"description"`
		Commands     []string      `json:"commands"`
		Prerequisites []Prerequisite `json:"prerequisites"`
	}

	// Try to parse the content as JSON
	err = json.Unmarshal([]byte(content), &jsonResponse)
	if err != nil {
		// If we failed to parse the JSON, the response might be wrapped in markdown code block
		if strings.Contains(content, "```json") && strings.Contains(content, "```") {
			// Extract content between ```json and ```
			jsonMatch := regexp.MustCompile("```json\\s*([\\s\\S]*?)```").FindStringSubmatch(content)
			if len(jsonMatch) > 1 {
				jsonContent := jsonMatch[1]
				// Try to parse the extracted JSON
				err = json.Unmarshal([]byte(jsonContent), &jsonResponse)
			}
		}
		
		// If we still failed, return an error
		if err != nil {
			return RepositoryAnalysis{}, fmt.Errorf("failed to parse OpenAI response as JSON: %w", err)
		}
	}

	// Convert the parsed JSON to our RepositoryAnalysis struct
	analysis := RepositoryAnalysis{
		Description:   jsonResponse.Description,
		CommandsToRun: jsonResponse.Commands,
		Prerequisites: jsonResponse.Prerequisites,
		Setup:         jsonResponse.Commands, // Use the same commands for Setup to maintain compatibility
	}

	log.Printf("Extracted Setup Instructions: %v", analysis.Setup)
	log.Printf("Extracted Commands: %v", analysis.CommandsToRun)
	log.Printf("Extracted Prerequisites: %v", analysis.Prerequisites)

	return analysis, nil
}

// TroubleshootError generates troubleshooting instructions for an error
func (s *OpenAIService) TroubleshootError(errorMessage, contextStr string) (string, error) {
	ctx := context.Background()
	
	// Create the messages and prompt
	prompt := fmt.Sprintf("I encountered this error while working with a repository:\n\n%s\n\nContext: %s\n\nPlease provide troubleshooting steps and a potential solution.", errorMessage, contextStr)
	
	// Create the chat completion
	completion, err := s.client.Chat.Completions.New(ctx, openai.ChatCompletionNewParams{
		Messages: openai.F([]openai.ChatCompletionMessageParamUnion{
			openai.SystemMessage("You are a helpful programming assistant specializing in troubleshooting development environment issues."),
			openai.UserMessage(prompt),
		}),
		Model:       openai.F(s.model),
		Temperature: openai.Float(0.7),
	})
	
	if err != nil {
		return "", fmt.Errorf("failed to get troubleshooting advice: %w", err)
	}
	
	if len(completion.Choices) == 0 {
		return "", errors.New("no troubleshooting advice received")
	}
	
	return completion.Choices[0].Message.Content, nil
}

// getDirectoryStructure generates a simplified directory tree structure starting from rootPath
func getDirectoryStructure(rootPath string, maxDepth int) (string, error) {
	var result strings.Builder
	baseName := filepath.Base(rootPath)
	result.WriteString(baseName + "/\n")

	err := walkDirectoryStructure(rootPath, &result, "", 0, maxDepth)
	if err != nil {
		return "", err
	}

	return result.String(), nil
}

// walkDirectoryStructure recursively walks the directory structure up to maxDepth
func walkDirectoryStructure(path string, output *strings.Builder, indent string, depth, maxDepth int) error {
	if depth >= maxDepth {
		return nil
	}

	files, err := os.ReadDir(path)
	if err != nil {
		return err
	}

	// Sort files and directories to make output consistent
	sort.Slice(files, func(i, j int) bool {
		// Directories come first, then files
		if files[i].IsDir() != files[j].IsDir() {
			return files[i].IsDir()
		}
		return files[i].Name() < files[j].Name()
	})

	for i, file := range files {
		if shouldSkip(file.Name()) {
			continue
		}

		// Determine the prefix for this item
		var linePrefix string
		if i == len(files)-1 {
			linePrefix = indent + "└── "
			// Next level indent
			nextIndent := indent + "    "
			if file.IsDir() {
				output.WriteString(linePrefix + file.Name() + "/\n")
				nextPath := filepath.Join(path, file.Name())
				err := walkDirectoryStructure(nextPath, output, nextIndent, depth+1, maxDepth)
				if err != nil {
					return err
				}
			} else {
				output.WriteString(linePrefix + file.Name() + "\n")
			}
		} else {
			linePrefix = indent + "├── "
			// Next level indent
			nextIndent := indent + "│   "
			if file.IsDir() {
				output.WriteString(linePrefix + file.Name() + "/\n")
				nextPath := filepath.Join(path, file.Name())
				err := walkDirectoryStructure(nextPath, output, nextIndent, depth+1, maxDepth)
				if err != nil {
					return err
				}
			} else {
				output.WriteString(linePrefix + file.Name() + "\n")
			}
		}
	}

	return nil
}

// shouldSkip returns true if the filename should be skipped in the directory structure
func shouldSkip(filename string) bool {
	// Skip hidden files and common directories to avoid noise
	if strings.HasPrefix(filename, ".") {
		return true
	}
	
	// Skip common large directories that don't help with command context
	skipDirs := map[string]bool{
		"node_modules": true,
		"vendor":      true,
		"dist":        true,
		"build":       true,
		".git":        true,
	}
	
	return skipDirs[filename]
}

// RepositoryAnalysis is the structured response from repository analysis
type RepositoryAnalysis struct {
	Description   string        `json:"description"`
	CommandsToRun []string      `json:"commands"`
	Prerequisites []Prerequisite `json:"prerequisites"`
	Setup         []string      `json:"setup,omitempty"`
}

// Prerequisite represents a required dependency for the repository
type Prerequisite struct {
	Name            string `json:"name"`
	Description     string `json:"description,omitempty"`
	InstallCommand  string `json:"installCommand,omitempty"`
}

func getRepositoryReadmeContent(repoPath string) (string, error) {
	readmeFiles, err := filepath.Glob(filepath.Join(repoPath, "README*"))
	if err != nil {
		return "", err
	}

	if len(readmeFiles) == 0 {
		return "", errors.New("no README file found")
	}

	readmeContent, err := os.ReadFile(readmeFiles[0])
	if err != nil {
		return "", err
	}

	return string(readmeContent), nil
}

func getMakefileContent(repoPath string) (string, error) {
	// Check for both "Makefile" and "makefile" (case-sensitive and case-insensitive systems)
	makefilePaths := []string{
		filepath.Join(repoPath, "Makefile"),
		filepath.Join(repoPath, "makefile"),
	}
	
	for _, path := range makefilePaths {
		if fileExists(path) {
			content, err := os.ReadFile(path)
			if err != nil {
				return "", err
			}
			return string(content), nil
		}
	}
	
	return "", errors.New("no Makefile found")
}

func fileExists(filename string) bool {
	info, err := os.Stat(filename)
	if os.IsNotExist(err) {
		return false
	}
	return !info.IsDir()
}

func (s *OpenAIService) callOpenAI(ctx context.Context, prompt string) (string, error) {
	// Build the messages
	chatCompletion, err := s.client.Chat.Completions.New(ctx, openai.ChatCompletionNewParams{
		Messages: openai.F([]openai.ChatCompletionMessageParamUnion{
			openai.SystemMessage(prompt),
			openai.UserMessage("Analyze this repository and provide your response as a clean JSON object with description, prerequisites, and commands. Do NOT include any markdown formatting or backticks in your response."),
		}),
		Model: openai.F(s.model),
	})

	if err != nil {
		return "", fmt.Errorf("OpenAI API error: %w", err)
	}

	if len(chatCompletion.Choices) == 0 {
		return "", errors.New("no response from OpenAI")
	}

	content := chatCompletion.Choices[0].Message.Content
	log.Printf("AI Response: %s", content)

	return content, nil
}
