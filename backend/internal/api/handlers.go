package api

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/prathyushnallamothu/startit/backend/internal/ai"
	"github.com/prathyushnallamothu/startit/backend/internal/executor"
	"github.com/prathyushnallamothu/startit/backend/internal/git"
)

// Response represents a standardized API response
type Response struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// CloneRequest represents a request to clone a repository
type CloneRequest struct {
	URL      string `json:"url" binding:"required"`
	Branch   string `json:"branch"`
	DestPath string `json:"destPath"`
}

// AnalyzeRepositoryRequest represents a request to analyze a repository
type AnalyzeRepositoryRequest struct {
	RepoPath string `json:"repoPath" binding:"required"`
}

// AnalyzeRepositoryResponse contains the results of repository analysis
type AnalyzeRepositoryResponse struct {
	Description   string              `json:"description"`
	SetupSteps    []string            `json:"setupSteps"`
	Commands      []string            `json:"commands"`
	Prerequisites []ai.Prerequisite   `json:"prerequisites"`
}

// ExecuteRequest represents a request to execute a command
type ExecuteRequest struct {
	Command   string   `json:"command" binding:"required"`
	Args      []string `json:"args"`
	Directory string   `json:"directory"`
}

// ExecuteCommandRequest represents a request to execute a command
type ExecuteCommandRequest struct {
	Command  string `json:"command" binding:"required"`
	RepoPath string `json:"repoPath" binding:"required"`
}

// ExecuteCommandResponse contains the results of command execution
type ExecuteCommandResponse struct {
	Output    string `json:"output"`
	ExitCode  int    `json:"exitCode"`
}

// TroubleshootRequest represents a request for troubleshooting help
type TroubleshootRequest struct {
	Error    string `json:"error" binding:"required"`
	RepoPath string `json:"repoPath" binding:"required"`
	Context  string `json:"context"`
}


// HandleRepositoryClone handles the repository clone endpoint
func HandleRepositoryClone(c *gin.Context) {
	var req CloneRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate the URL
	if req.URL == "" || !isValidGitURL(req.URL) {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Invalid git repository URL",
		})
		return
	}

	// Determine destination path
	destPath := req.DestPath
	if destPath == "" {
		// Use a temporary directory
		tempBaseDir := filepath.Join(os.TempDir(), "startit-repos")
		if err := os.MkdirAll(tempBaseDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, Response{
				Success: false,
				Error:   "Failed to create temp directory: " + err.Error(),
			})
			return
		}

		// Create a unique directory name based on the repo name and a UUID
		repo := git.NewRepository(req.URL, req.Branch, "")
		repoName := repo.GetRepositoryName()
		uniqueID := uuid.New().String()[:8]
		destPath = filepath.Join(tempBaseDir, repoName+"-"+uniqueID)
	}

	// Create a new repository instance
	repo := git.NewRepository(req.URL, req.Branch, destPath)

	// Clone the repository
	if err := repo.Clone(); err != nil {
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Failed to clone repository: " + err.Error(),
		})
		return
	}

	// Return the repository details
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data: map[string]interface{}{
			"url":       req.URL,
			"branch":    repo.Branch,
			"localPath": destPath,
		},
	})
}

// HandleRepositoryAnalyze handles a request to analyze a repository
func HandleRepositoryAnalyze(c *gin.Context) {
	var req AnalyzeRepositoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate the repository path
	repoPath := req.RepoPath
	if !pathExists(repoPath) {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Repository path does not exist",
		})
		return
	}

	// Get repository information
	repo, err := git.OpenRepository(repoPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Failed to open repository: " + err.Error(),
		})
		return
	}

	// Create OpenAI service
	openAIService, err := ai.NewOpenAIService()
	if err != nil {
		log.Printf("ERROR: Failed to initialize AI service: %v", err)
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Failed to initialize AI service: " + err.Error(),
		})
		return
	}

	// Analyze the repository
	log.Printf("Analyzing repository: %s", repoPath)
	analysis, err := openAIService.AnalyzeRepository(c.Request.Context(), repo)
	if err != nil {
		log.Printf("ERROR: Failed to analyze repository: %v", err)
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Failed to analyze repository: " + err.Error(),
		})
		return
	}

	// Respond with the analysis results
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data: AnalyzeRepositoryResponse{
			Description:   analysis.Description,
			SetupSteps:    analysis.Setup,
			Commands:      analysis.CommandsToRun,
			Prerequisites: analysis.Prerequisites,
		},
	})
}

// HandleCommandExecution handles a request to execute a command
func HandleCommandExecution(c *gin.Context) {
	var req ExecuteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate the command
	command := req.Command
	if command == "" {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Command cannot be empty",
		})
		return
	}

	// Initialize the command executor
	cmdExecutor := executor.NewCommandExecutor()

	// Execute the command
	log.Printf("API: Executing command: '%s' with args: %v in directory: %s", command, req.Args, req.Directory)
	
	ctx := context.Background()
	var result *executor.CommandResult
	var err error
	
	// Handle more complex commands that might contain pipes, redirects, etc.
	if strings.Contains(command, "|") || 
	   strings.Contains(command, ">") || 
	   strings.Contains(command, "<") ||
	   strings.Contains(command, "&&") ||
	   strings.Contains(command, ";") {
		// For complex commands, use the shell executor
		result, err = executor.ExecuteShellCommand(ctx, command, req.Directory, 5*time.Minute)
	} else {
		// For simple commands, use the regular executor
		result, err = cmdExecutor.Execute(command, req.Args, req.Directory)
	}
	
	// Handle errors that prevent command execution (not just non-zero exit codes)
	if err != nil {
		log.Printf("API: Command execution error: %v", err)
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Command execution error: " + err.Error(),
		})
		return
	}

	// Check exit code - non-zero means command ran but failed
	if result.ExitCode != 0 {
		log.Printf("API: Command executed with non-zero exit code: %d", result.ExitCode)
		
		// Format the result for JSON marshaling
		jsonResult := map[string]interface{}{
			"command":   result.Command,
			"args":      result.Args,
			"exitCode":  result.ExitCode,
			"output":    result.Output,
			"error":     result.Error,
			"startTime": result.StartTime.Format(time.RFC3339),
			"endTime":   result.EndTime.Format(time.RFC3339),
			"duration":  result.Duration,
		}
		
		// Return a 200 status but with success=false to indicate command ran but failed
		c.JSON(http.StatusOK, Response{
			Success: false, // Command ran but failed with non-zero exit code
			Error:   fmt.Sprintf("Command exited with code %d: %s", result.ExitCode, result.Error),
			Data:    jsonResult,
		})
		return
	}

	log.Printf("API: Command executed successfully with exit code: %d", result.ExitCode)

	// Format the result for JSON marshaling
	jsonResult := map[string]interface{}{
		"command":   result.Command,
		"args":      result.Args,
		"exitCode":  result.ExitCode,
		"output":    result.Output,
		"error":     result.Error,
		"startTime": result.StartTime.Format(time.RFC3339),
		"endTime":   result.EndTime.Format(time.RFC3339),
		"duration":  result.Duration,
	}

	// Return the execution results
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data:    jsonResult,
	})
}

// HandleExecuteCommand handles a request to execute a command in a repository
func HandleExecuteCommand(c *gin.Context) {
	var req ExecuteCommandRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Check if the repository path exists
	if !pathExists(req.RepoPath) {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Repository path does not exist",
		})
		return
	}

	// Create and configure the executor
	cmdExecutor := executor.NewCommandExecutor()
	
	log.Printf("API: Executing command in repository: '%s' in path: %s", req.Command, req.RepoPath)
	
	// Handle more complex commands with pipes, redirects, etc.
	ctx := context.Background()
	var result *executor.CommandResult
	var err error
	
	if strings.Contains(req.Command, "|") || 
	   strings.Contains(req.Command, ">") || 
	   strings.Contains(req.Command, "<") ||
	   strings.Contains(req.Command, "&&") ||
	   strings.Contains(req.Command, ";") {
		// For complex commands, use the shell executor
		result, err = executor.ExecuteShellCommand(ctx, req.Command, req.RepoPath, 5*time.Minute)
	} else {
		// For simple commands, use the regular executor with the provided command, args, and directory
		result, err = cmdExecutor.Execute(req.Command, nil, req.RepoPath)
	}
	
	if err != nil {
		log.Printf("API: Repository command execution failed: %v", err)
		
		// If there's an error, we'll try to provide helpful troubleshooting
		openAIService, serviceErr := ai.NewOpenAIService()
		if serviceErr == nil {
			troubleshootingAdvice, adviceErr := openAIService.TroubleshootError(err.Error(), req.Command)
			if adviceErr == nil {
				c.JSON(http.StatusInternalServerError, Response{
					Success: false,
					Error:   fmt.Sprintf("Command execution failed: %v\n\nTroubleshooting Advice:\n%s", err, troubleshootingAdvice),
				})
				return
			}
		}

		// If we couldn't get AI troubleshooting, just return the error
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   fmt.Sprintf("Command execution failed: %v", err),
		})
		return
	}

	// Even if the command ran, it might have had a non-zero exit code
	if result.ExitCode != 0 {
		log.Printf("API: Repository command executed with non-zero exit code: %d", result.ExitCode)
		
		// Try to get troubleshooting advice for the error
		errorMessage := fmt.Sprintf("Command exited with code %d", result.ExitCode)
		if result.Error != "" {
			errorMessage += ": " + result.Error
		}
		
		openAIService, serviceErr := ai.NewOpenAIService()
		if serviceErr == nil {
			troubleshootingAdvice, adviceErr := openAIService.TroubleshootError(errorMessage, req.Command)
			if adviceErr == nil {
				c.JSON(http.StatusOK, Response{
					Success: false,
					Error:   fmt.Sprintf("%s\n\nTroubleshooting Advice:\n%s", errorMessage, troubleshootingAdvice),
					Data: ExecuteCommandResponse{
						Output: result.Output,
						ExitCode: result.ExitCode,
					},
				})
				return
			}
		}
		
		// If we couldn't get AI troubleshooting, return the command result with success=false
		c.JSON(http.StatusOK, Response{
			Success: false,
			Error:   errorMessage,
			Data: ExecuteCommandResponse{
				Output: result.Output,
				ExitCode: result.ExitCode,
			},
		})
		return
	}

	log.Printf("API: Repository command executed successfully with exit code 0")
	
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data: ExecuteCommandResponse{
			Output: result.Output,
			ExitCode: result.ExitCode,
		},
	})
}

// HandleTroubleshooting handles the troubleshooting endpoint
func HandleTroubleshooting(c *gin.Context) {
	var req TroubleshootRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Initialize OpenAI service
	openAIService, err := ai.NewOpenAIService()
	if err != nil {
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Failed to initialize AI service: " + err.Error(),
		})
		return
	}

	// Get troubleshooting advice
	solution, err := openAIService.TroubleshootError(req.Error, req.RepoPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, Response{
			Success: false,
			Error:   "Failed to get troubleshooting advice: " + err.Error(),
		})
		return
	}

	// Return the troubleshooting results
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data: map[string]interface{}{
			"solution": solution,
		},
	})
}

// HandleGetCommandStatus handles a request to get the status of a background command
func HandleGetCommandStatus(c *gin.Context) {
	commandID := c.Param("id")
	if commandID == "" {
		c.JSON(http.StatusBadRequest, Response{
			Success: false,
			Error:   "Command ID is required",
		})
		return
	}

	// Get the background command manager
	bgManager := executor.GetBackgroundManager()

	// Get the command status
	bgCmd, exists := bgManager.GetCommandStatus(commandID)
	if !exists {
		c.JSON(http.StatusNotFound, Response{
			Success: false,
			Error:   "Command not found",
		})
		return
	}

	// Check if the command is completed
	isCompleted := bgCmd.Status == executor.StatusCompleted || 
				bgCmd.Status == executor.StatusFailed || 
				bgCmd.Status == executor.StatusTimeout

	// Build a proper response with result and error handling
	responseData := map[string]interface{}{
		"commandId":   bgCmd.ID,
		"status":      string(bgCmd.Status),
		"startTime":   bgCmd.StartTime,
		"isCompleted": isCompleted,
	}

	// Add the end time if it's set
	if bgCmd.EndTime != nil {
		responseData["endTime"] = bgCmd.EndTime
	}

	// Add current output and error, even if command is still running
	output := bgCmd.GetCurrentOutput()
	if output != "" {
		responseData["currentOutput"] = output
	}

	errorOut := bgCmd.GetCurrentError()
	if errorOut != "" {
		responseData["currentError"] = errorOut
	}

	// Handle the command result (final result when completed)
	if bgCmd.Result != nil {
		// Convert the CommandResult to a map to avoid JSON serialization issues
		responseData["result"] = map[string]interface{}{
			"command":   bgCmd.Result.Command,
			"args":      bgCmd.Result.Args,
			"output":    bgCmd.Result.Output,
			"error":     bgCmd.Result.Error,
			"exitCode":  bgCmd.Result.ExitCode,
			"startTime": bgCmd.Result.StartTime,
			"endTime":   bgCmd.Result.EndTime,
			"duration":  bgCmd.Result.Duration,
		}
	}

	// Handle the error message
	if bgCmd.Error != "" {
		responseData["error"] = bgCmd.Error
	}

	c.JSON(http.StatusOK, Response{
		Success: true,
		Data:    responseData,
	})
}

// Helper function to check if a path exists
func pathExists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

// Helper function to validate a Git URL
func isValidGitURL(url string) bool {
	// Check for standard formats
	if strings.HasPrefix(url, "http://") ||
		strings.HasPrefix(url, "https://") ||
		strings.HasPrefix(url, "git@") {
		return true
	}

	// Check for shorthand GitHub formats (user/repo or github.com/user/repo)
	if strings.Count(url, "/") == 1 {
		// Simple user/repo format
		return true
	} else if strings.HasPrefix(url, "github.com/") && strings.Count(url, "/") >= 2 {
		// github.com/user/repo format
		return true
	}

	return false
}
