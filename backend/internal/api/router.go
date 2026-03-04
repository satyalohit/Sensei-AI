package api

import (
	"net/http"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)



// NewRouter creates and configures a new router with all API routes
func NewRouter() *gin.Engine {
	r := gin.Default()

	// CORS configuration
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// API routes
	api := r.Group("/api")
	{
		// Repository routes
		repo := api.Group("/repository")
		{
			repo.POST("/clone", HandleRepositoryClone)
			repo.POST("/analyze", HandleRepositoryAnalyze)
		}

		// Command execution routes
		api.POST("/execute-command", HandleExecuteCommand)
		api.POST("/command", HandleExecuteCommand) // Keep old endpoint for backward compatibility
		api.POST("/background-command", HandleExecuteBackgroundCommand)
		api.GET("/command-status/:id", HandleGetCommandStatus)

		// LLM routes
		api.POST("/troubleshoot", HandleTroubleshooting)
	}

	// Start background cleanup task
	StartBackgroundCleanupTask()

	return r
}

// RespondWithSuccess sends a JSON success response
func RespondWithSuccess(c *gin.Context, status int, data interface{}) {
	c.JSON(status, Response{
		Success: true,
		Data:    data,
	})
}

// RespondWithError sends a JSON error response
func RespondWithError(c *gin.Context, status int, message string) {
	c.JSON(status, Response{
		Success: false,
		Error:   message,
	})
}
