package executor

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"bufio"
)

// CommandResult represents the result of a command execution
type CommandResult struct {
	Command   string    `json:"command"`
	Args      string    `json:"args"`
	ExitCode  int       `json:"exitCode"`
	Output    string    `json:"output"`
	Error     string    `json:"error,omitempty"`
	StartTime time.Time `json:"startTime"`
	EndTime   time.Time `json:"endTime"`
	Duration  string    `json:"duration"`
}

// CommandExecutor handles executing system commands
type CommandExecutor struct {
	ShellPath string        // Path to the shell executable
	timeout   time.Duration // Default timeout for command execution
}

// NewCommandExecutor creates a new CommandExecutor
func NewCommandExecutor() *CommandExecutor {
	// Default to bash on Unix-like systems, cmd on Windows
	shellPath := "/bin/bash"
	if _, err := os.Stat(shellPath); os.IsNotExist(err) {
		// Try to find a suitable shell
		for _, shell := range []string{"/bin/zsh", "/bin/sh"} {
			if _, err := os.Stat(shell); err == nil {
				shellPath = shell
				break
			}
		}
	}
	
	return &CommandExecutor{
		ShellPath: shellPath,
		timeout:   5 * time.Minute, // Default timeout of 5 minutes
	}
}

// SetTimeout sets the timeout for command execution
func (e *CommandExecutor) SetTimeout(timeout time.Duration) {
	e.timeout = timeout
}

// Execute runs a command and returns the result
func (e *CommandExecutor) Execute(command string, args []string, workDir string) (*CommandResult, error) {
	startTime := time.Now()
	
	// Create a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), e.timeout)
	defer cancel()

	// Prepare the command
	cmd := exec.CommandContext(ctx, e.ShellPath, "-c", command)
	if workDir != "" {
		if _, err := os.Stat(workDir); os.IsNotExist(err) {
			return nil, fmt.Errorf("working directory does not exist: %s", workDir)
		}
		cmd.Dir = workDir
	}

	// Capture stdout and stderr
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	// Execute the command
	err := cmd.Run()
	endTime := time.Now()
	duration := endTime.Sub(startTime)

	// Prepare the result
	result := &CommandResult{
		Command:   command,
		Args:      strings.Join(args, " "),
		Output:    stdout.String(),
		StartTime: startTime,
		EndTime:   endTime,
		Duration:  duration.String(),
	}

	// Handle command execution errors
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return result, fmt.Errorf("command timed out after %s", e.timeout)
		}

		// Get the exit code if possible
		if exitError, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exitError.ExitCode()
		} else {
			result.ExitCode = -1
		}
		
		result.Error = stderr.String()
		return result, nil
	}

	// Command executed successfully
	result.ExitCode = 0
	return result, nil
}

// ExecuteCommand executes a command in the specified repository directory
func (e *CommandExecutor) ExecuteCommand(command, repoPath string) (string, error) {
	// Safety check for potentially unsafe commands
	if containsUnsafeCommand(command) {
		return "", fmt.Errorf("command contains potentially unsafe operations: %s", command)
	}

	// Split the command into command and arguments
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return "", errors.New("empty command")
	}

	cmd := parts[0]
	var args []string
	if len(parts) > 1 {
		args = parts[1:]
	}

	// Execute the command
	ctx, cancel := context.WithTimeout(context.Background(), e.timeout)
	defer cancel()

	result, err := ExecuteCommand(ctx, cmd, args, repoPath, e.timeout)
	if err != nil {
		return "", err
	}

	// If there's an error in the command execution, include it in the output
	if result.ExitCode != 0 {
		return fmt.Sprintf("%s\nError: %s", result.Output, result.Error), fmt.Errorf("command exited with code %d", result.ExitCode)
	}

	return result.Output, nil
}

// ExecuteCommand executes a shell command with a timeout
func ExecuteCommand(ctx context.Context, command string, args []string, dir string, timeout time.Duration) (*CommandResult, error) {
	// Create a new context with timeout if provided
	if timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, timeout)
		defer cancel()
	}

	// Log the command execution
	log.Printf("Executing command: %s %s in directory: %s", command, strings.Join(args, " "), dir)

	// Prepare the command
	cmd := exec.CommandContext(ctx, command, args...)
	if dir != "" {
		cmd.Dir = dir
	}

	// Set up buffers for stdout and stderr
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	// Record start time
	startTime := time.Now()

	// Execute the command
	err := cmd.Run()

	// Record end time
	endTime := time.Now()
	duration := endTime.Sub(startTime).String()

	// Prepare the result
	result := &CommandResult{
		Command:   command,
		Args:      strings.Join(args, " "),
		Output:    stdout.String(),
		StartTime: startTime,
		EndTime:   endTime,
		Duration:  duration,
	}

	// Handle errors
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			result.ExitCode = exitErr.ExitCode()
			log.Printf("Command exited with code %d: %s %s", result.ExitCode, command, strings.Join(args, " "))
		} else if errors.Is(err, context.DeadlineExceeded) {
			log.Printf("Command timed out after %s: %s %s", timeout.String(), command, strings.Join(args, " "))
			return nil, fmt.Errorf("command timed out after %s", timeout.String())
		} else {
			log.Printf("Failed to execute command: %v", err)
			return nil, fmt.Errorf("failed to execute command: %w", err)
		}
		result.Error = stderr.String()
	} else {
		result.ExitCode = 0
		log.Printf("Command executed successfully: %s %s", command, strings.Join(args, " "))
	}

	// Log command output summary
	if len(result.Output) > 0 {
		outputPreview := result.Output
		if len(outputPreview) > 100 {
			outputPreview = outputPreview[:100] + "..."
		}
		log.Printf("Command output: %s", outputPreview)
	}
	
	if len(result.Error) > 0 {
		log.Printf("Command error: %s", result.Error)
	}

	return result, nil
}

// ExecuteCommands executes a list of commands sequentially
// If stopOnError is true, execution will stop on the first error
func ExecuteCommands(ctx context.Context, commands []string, dir string, stopOnError bool) ([]*CommandResult, error) {
	log.Printf("Executing %d commands in directory: %s", len(commands), dir)
	results := make([]*CommandResult, 0, len(commands))

	for i, cmdStr := range commands {
		log.Printf("Executing command %d/%d: %s", i+1, len(commands), cmdStr)
		
		// Split the command string into command and args
		parts := strings.Fields(cmdStr)
		if len(parts) == 0 {
			log.Printf("Skipping empty command")
			continue
		}

		command := parts[0]
		var args []string
		if len(parts) > 1 {
			args = parts[1:]
		}

		// Execute the command
		result, err := ExecuteCommand(ctx, command, args, dir, 0)
		if err != nil {
			log.Printf("Command %d/%d failed: %v", i+1, len(commands), err)
			if stopOnError {
				return results, err
			}
			// Create a result for the failed command
			results = append(results, &CommandResult{
				Command:   command,
				Args:      strings.Join(args, " "),
				ExitCode:  -1,
				Error:     err.Error(),
				StartTime: time.Now(),
				EndTime:   time.Now(),
				Duration:  "0s",
			})
			continue
		}

		results = append(results, result)

		// Stop if the command failed and stopOnError is true
		if result.ExitCode != 0 && stopOnError {
			log.Printf("Stopping command execution after failure of command %d/%d", i+1, len(commands))
			break
		}
	}

	log.Printf("Completed execution of %d/%d commands", len(results), len(commands))
	return results, nil
}

// ParseCommandString parses a shell command string that may contain pipes, redirects, etc.
func ParseCommandString(commandStr string) (string, []string, error) {
	// Remove any backticks or other shell-specific markers
	commandStr = strings.Trim(commandStr, "`'\"")
	
	// For now, we'll handle simple cases by passing the whole string to shell
	// For complex commands with pipes or redirects, we'll use the shell itself
	if strings.Contains(commandStr, "|") || 
	   strings.Contains(commandStr, ">") || 
	   strings.Contains(commandStr, "<") ||
	   strings.Contains(commandStr, "&&") ||
	   strings.Contains(commandStr, ";") {
		return "/bin/sh", []string{"-c", commandStr}, nil
	}
	
	// For simple commands, split into command and args
	parts := strings.Fields(commandStr)
	if len(parts) == 0 {
		return "", nil, errors.New("empty command")
	}
	
	command := parts[0]
	var args []string
	if len(parts) > 1 {
		args = parts[1:]
	}
	
	return command, args, nil
}

// ExecuteShellCommand executes a shell command string that might contain pipes, redirects, etc.
func ExecuteShellCommand(ctx context.Context, commandStr string, dir string, timeout time.Duration) (*CommandResult, error) {
	// Parse the command string
	shell, args, err := ParseCommandString(commandStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse command: %w", err)
	}
	
	// Use the ExecuteCommand function to execute the shell command
	result, err := ExecuteCommand(ctx, shell, args, dir, timeout)
	
	// Even if command fails with non-zero exit code, we still want to return the result
	if err != nil && result != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			// This is a normal command failure with non-zero exit code
			// Don't treat it as an error, but include the exit code in the result
			return result, nil
		}
	}
	
	return result, err
}

// ExecuteCommandWithStreaming executes a command and streams output in real-time
func ExecuteCommandWithStreaming(ctx context.Context, command string, args []string, dir string, timeout time.Duration,
	onStdout func(string), onStderr func(string)) (*CommandResult, error) {
	// Create a new context with timeout if provided
	if timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, timeout)
		defer cancel()
	}

	// Log the command execution
	log.Printf("Executing command with streaming: %s %s in directory: %s", command, strings.Join(args, " "), dir)

	// Prepare the command
	cmd := exec.CommandContext(ctx, command, args...)
	if dir != "" {
		cmd.Dir = dir
	}

	// Create pipes for stdout and stderr
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stdout pipe: %w", err)
	}

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to create stderr pipe: %w", err)
	}

	// Set up buffers to collect all output
	var stdoutBuffer, stderrBuffer bytes.Buffer

	// Start the command
	startTime := time.Now()
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start command: %w", err)
	}

	// Create a wait group for both stdout and stderr goroutines
	var wg sync.WaitGroup
	wg.Add(2)

	// Process stdout
	go func() {
		defer wg.Done()

		scanner := bufio.NewScanner(stdoutPipe)
		for scanner.Scan() {
			line := scanner.Text() + "\n"
			stdoutBuffer.WriteString(line)
			if onStdout != nil {
				onStdout(line)
			}
		}
	}()

	// Process stderr
	go func() {
		defer wg.Done()

		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			line := scanner.Text() + "\n"
			stderrBuffer.WriteString(line)
			if onStderr != nil {
				onStderr(line)
			}
		}
	}()

	// Wait for both stdout and stderr to be fully read
	wg.Wait()

	// Wait for command to finish
	err = cmd.Wait()

	// Record end time
	endTime := time.Now()
	duration := endTime.Sub(startTime).String()

	// Prepare the result
	result := &CommandResult{
		Command:   command,
		Args:      strings.Join(args, " "),
		Output:    stdoutBuffer.String(),
		Error:     stderrBuffer.String(),
		StartTime: startTime,
		EndTime:   endTime,
		Duration:  duration,
	}

	// Handle errors
	if err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			result.ExitCode = exitErr.ExitCode()
			log.Printf("Command exited with code %d: %s %s", result.ExitCode, command, strings.Join(args, " "))
		} else {
			log.Printf("Error executing command: %v", err)
			return result, fmt.Errorf("failed to execute command: %w", err)
		}
	} else {
		result.ExitCode = 0
		log.Printf("Command executed successfully: %s %s", command, strings.Join(args, " "))
	}

	return result, nil
}

// ExecuteShellCommandWithStreaming executes a shell command with streaming output
func ExecuteShellCommandWithStreaming(ctx context.Context, commandStr string, dir string, timeout time.Duration,
	onStdout func(string), onStderr func(string)) (*CommandResult, error) {
	// Parse the command string
	shell, args, err := ParseCommandString(commandStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse command: %w", err)
	}

	// Use the ExecuteCommandWithStreaming function
	result, err := ExecuteCommandWithStreaming(ctx, shell, args, dir, timeout, onStdout, onStderr)

	// Even if command fails with non-zero exit code, we still want to return the result
	if err != nil && result != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			// This is a normal command failure with non-zero exit code
			// Don't treat it as an error, but include the exit code in the result
			return result, nil
		}
	}

	return result, err
}

// containsUnsafeCommand checks if a command contains potentially unsafe operations
func containsUnsafeCommand(command string) bool {
	// List of potentially dangerous commands or arguments
	unsafePatterns := []string{
		"rm -rf /", "rm -rf /*", "rm -rf ~", "rm -rf .", "rm -rf *",
		"> /dev/sda", "> /dev/hda",
		"mkfs", "dd if=/dev/zero",
		":(){:|:&};:", ":(){ :|:& };:", // Fork bomb patterns
	}
	
	commandLower := strings.ToLower(command)
	for _, pattern := range unsafePatterns {
		if strings.Contains(commandLower, pattern) {
			return true
		}
	}
	
	return false
}
