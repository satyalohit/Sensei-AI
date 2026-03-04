package api

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/prathyushnallamothu/startit/backend/internal/executor"
)

// BackgroundCommandRequest represents a request to execute a command in the background
type BackgroundCommandRequest struct {
	Command  string `json:"command" binding:"required"`
	RepoPath string `json:"repoPath" binding:"required"`
}

// HandleExecuteBackgroundCommand handles a request to execute a command in the background
func HandleExecuteBackgroundCommand(c *gin.Context) {
	var req BackgroundCommandRequest
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

	// Get the background command manager
	bgManager := executor.GetBackgroundManager()

	// Execute the command in the background
	commandID := bgManager.ExecuteCommandInBackground(req.Command, req.RepoPath)

	// Return the command ID to the client
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data: map[string]interface{}{
			"commandId": commandID,
		},
	})
}

// Do not redefine HandleGetCommandStatus here, it is already defined in handlers.go

// StartBackgroundCleanupTask starts a background task to clean up completed commands
func StartBackgroundCleanupTask() {
	go func() {
		for {
			// Clean up commands that completed more than 1 hour ago
			executor.GetBackgroundManager().CleanupCompletedCommands(1 * time.Hour)
			
			// Sleep for 10 minutes
			time.Sleep(10 * time.Minute)
		}
	}()
}
