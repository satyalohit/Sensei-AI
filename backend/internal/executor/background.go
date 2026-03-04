package executor

import (
	"context"
	"log"
	"sync"
	"strings"
	"time"
)

// CommandStatus represents the status of a background command
type CommandStatus string

const (
	StatusPending   CommandStatus = "pending"
	StatusRunning   CommandStatus = "running"
	StatusCompleted CommandStatus = "completed"
	StatusFailed    CommandStatus = "failed"
	StatusTimeout   CommandStatus = "timeout"
)

// BackgroundCommand represents a command running in the background
type BackgroundCommand struct {
	ID           string         `json:"id"`
	Command      string         `json:"command"`
	RepoPath     string         `json:"repoPath"`
	Status       CommandStatus  `json:"status"`
	StartTime    time.Time      `json:"startTime"`
	EndTime      *time.Time     `json:"endTime,omitempty"`
	Result       *CommandResult `json:"result,omitempty"`
	Error        string         `json:"error,omitempty"`
	currentOutput string         `json:"currentOutput,omitempty"`
	currentError  string         `json:"currentError,omitempty"`
	mutex        sync.Mutex     `json:"-"`
}

// AppendOutput adds new output to the command's current output buffer
func (cmd *BackgroundCommand) AppendOutput(output string) {
	cmd.mutex.Lock()
	defer cmd.mutex.Unlock()
	cmd.currentOutput += output
}

// AppendError adds new error output to the command's current error buffer
func (cmd *BackgroundCommand) AppendError(errorText string) {
	cmd.mutex.Lock()
	defer cmd.mutex.Unlock()
	cmd.currentError += errorText
}

// GetCurrentOutput returns the current output buffer
func (cmd *BackgroundCommand) GetCurrentOutput() string {
	cmd.mutex.Lock()
	defer cmd.mutex.Unlock()
	return cmd.currentOutput
}

// GetCurrentError returns the current error buffer
func (cmd *BackgroundCommand) GetCurrentError() string {
	cmd.mutex.Lock()
	defer cmd.mutex.Unlock()
	return cmd.currentError
}

// BackgroundCommandManager manages commands running in the background
type BackgroundCommandManager struct {
	mutex    sync.RWMutex
	commands map[string]*BackgroundCommand
}

// NewBackgroundCommandManager creates a new background command manager
func NewBackgroundCommandManager() *BackgroundCommandManager {
	return &BackgroundCommandManager{
		commands: make(map[string]*BackgroundCommand),
	}
}

// singleton instance of the background command manager
var (
	backgroundManager     *BackgroundCommandManager
	backgroundManagerOnce sync.Once
)

// GetBackgroundManager returns the singleton instance of the background command manager
func GetBackgroundManager() *BackgroundCommandManager {
	backgroundManagerOnce.Do(func() {
		backgroundManager = NewBackgroundCommandManager()
	})
	return backgroundManager
}

// ExecuteCommandInBackground starts a command in the background and returns its ID
func (m *BackgroundCommandManager) ExecuteCommandInBackground(command, repoPath string) string {
	// Generate a unique ID for this command
	id := time.Now().Format("20060102150405") + "-" + command[:min(10, len(command))]

	// Create the background command object
	bgCmd := &BackgroundCommand{
		ID:        id,
		Command:   command,
		RepoPath:  repoPath,
		Status:    StatusPending,
		StartTime: time.Now(),
	}

	// Store the command in the manager
	m.mutex.Lock()
	m.commands[id] = bgCmd
	m.mutex.Unlock()

	// Start the command in a goroutine
	go func() {
		log.Printf("Starting background command [%s]: %s in %s", id, command, repoPath)
		bgCmd.Status = StatusRunning

		// Create context with timeout
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()

		// Execute the command
		var result *CommandResult
		var err error

		// Define output handlers that will update the real-time output buffers
		onStdout := func(output string) {
			bgCmd.AppendOutput(output)
			log.Printf("Command [%s] stdout: %s", id, strings.TrimSpace(output))
		}

		onStderr := func(errText string) {
			bgCmd.AppendError(errText)
			log.Printf("Command [%s] stderr: %s", id, strings.TrimSpace(errText))
		}

		// Handle more complex commands with pipes, redirects, etc.
		if isComplexCommand(command) {
			result, err = ExecuteShellCommandWithStreaming(ctx, command, repoPath, 10*time.Minute, onStdout, onStderr)
		} else {
			// For simple commands, parse and use the streaming executor
			cmd, args, parseErr := ParseCommandString(command)
			if parseErr != nil {
				err = parseErr
			} else {
				result, err = ExecuteCommandWithStreaming(ctx, cmd, args, repoPath, 10*time.Minute, onStdout, onStderr)
			}
		}

		// Update the command status based on the result
		m.mutex.Lock()
		defer m.mutex.Unlock()

		// Check if command still exists (it might have been removed)
		bgCmd, exists := m.commands[id]
		if !exists {
			log.Printf("Background command [%s] no longer exists in manager, discarding results", id)
			return
		}

		if err != nil {
			endTime := time.Now()
			bgCmd.EndTime = &endTime
			bgCmd.Error = err.Error()
			
			if err == context.DeadlineExceeded {
				bgCmd.Status = StatusTimeout
				log.Printf("Background command [%s] timed out", id)
			} else {
				bgCmd.Status = StatusFailed
				log.Printf("Background command [%s] failed: %v", id, err)
			}
		} else {
			endTime := time.Now()
			bgCmd.EndTime = &endTime
			bgCmd.Result = result
			
			if result.ExitCode != 0 {
				bgCmd.Status = StatusFailed
				log.Printf("Background command [%s] completed with non-zero exit code: %d", id, result.ExitCode)
			} else {
				bgCmd.Status = StatusCompleted
				log.Printf("Background command [%s] completed successfully", id)
			}
		}
	}()

	return id
}

// GetCommandStatus returns the status of a background command
func (m *BackgroundCommandManager) GetCommandStatus(id string) (*BackgroundCommand, bool) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	bgCmd, exists := m.commands[id]
	return bgCmd, exists
}

// CleanupCompletedCommands removes completed commands older than the specified duration
func (m *BackgroundCommandManager) CleanupCompletedCommands(olderThan time.Duration) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	now := time.Now()
	for id, cmd := range m.commands {
		// Only clean up completed or failed commands
		if (cmd.Status == StatusCompleted || cmd.Status == StatusFailed || cmd.Status == StatusTimeout) && 
		   cmd.EndTime != nil && now.Sub(*cmd.EndTime) > olderThan {
			delete(m.commands, id)
			log.Printf("Cleaned up background command [%s]", id)
		}
	}
}

// isComplexCommand checks if a command contains shell operators
func isComplexCommand(command string) bool {
	return contains(command, "|") || 
	       contains(command, ">") || 
	       contains(command, "<") ||
	       contains(command, "&&") ||
	       contains(command, ";")
}

// contains checks if a string contains a substring
func contains(s, substr string) bool {
	return strings.Contains(s, substr)
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
