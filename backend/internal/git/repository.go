package git

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Repository represents a Git repository
type Repository struct {
	URL      string
	Branch   string
	LocalDir string
}

// NewRepository creates a new Repository instance
func NewRepository(url, branch, localDir string) *Repository {
	if branch == "" {
		branch = "main"
	}

	return &Repository{
		URL:      url,
		Branch:   branch,
		LocalDir: localDir,
	}
}

// OpenRepository opens an existing local repository
func OpenRepository(localDir string) (*Repository, error) {
	if !dirExists(localDir) {
		return nil, fmt.Errorf("directory does not exist: %s", localDir)
	}
	
	// Check if this is a git repository by looking for .git directory
	gitDir := filepath.Join(localDir, ".git")
	if !dirExists(gitDir) {
		return nil, fmt.Errorf("not a git repository (missing .git directory): %s", localDir)
	}
	
	return &Repository{
		LocalDir: localDir,
	}, nil
}

// Clone clones a repository to the local filesystem
func (r *Repository) Clone() error {
	// Ensure the directory exists
	if err := os.MkdirAll(filepath.Dir(r.LocalDir), 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Check if directory already exists and is not empty
	if dirExists(r.LocalDir) {
		return fmt.Errorf("directory already exists and is not empty: %s", r.LocalDir)
	}

	// For public GitHub repositories, use HTTPS instead of SSH
	repoURL := r.URL
	if strings.Contains(repoURL, "github.com") && !strings.HasPrefix(repoURL, "https://") {
		repoURL = "https://" + strings.TrimPrefix(repoURL, "git@")
		repoURL = strings.Replace(repoURL, ":", "/", 1)
	}

	// Run git clone command
	cmd := exec.Command("git", "clone", "-b", r.Branch, repoURL, r.LocalDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Try with default branch if specified branch fails
		if r.Branch != "main" && r.Branch != "master" {
			// Try with main branch
			r.Branch = "main"
			cmd = exec.Command("git", "clone", "-b", r.Branch, repoURL, r.LocalDir)
			output, err = cmd.CombinedOutput()
			if err != nil {
				// Try with master branch
				r.Branch = "master"
				cmd = exec.Command("git", "clone", "-b", r.Branch, repoURL, r.LocalDir)
				output, err = cmd.CombinedOutput()
				if err != nil {
					// Just try without specifying a branch
					cmd = exec.Command("git", "clone", repoURL, r.LocalDir)
					output, err = cmd.CombinedOutput()
					if err != nil {
						return fmt.Errorf("git clone failed: %w - %s", err, string(output))
					}
				}
			}
		} else {
			return fmt.Errorf("git clone failed: %w - %s", err, string(output))
		}
	}

	return nil
}

// GetReadmeContent returns the content of the README file
func (r *Repository) GetReadmeContent() (string, error) {
	if !dirExists(r.LocalDir) {
		return "", errors.New("repository directory does not exist")
	}

	// Look for README files with different extensions and cases
	readmePatterns := []string{
		"README.md", "README.MD", "Readme.md",
		"README.txt", "README", "readme.md",
	}

	for _, pattern := range readmePatterns {
		readmePath := filepath.Join(r.LocalDir, pattern)
		if fileExists(readmePath) {
			content, err := os.ReadFile(readmePath)
			if err != nil {
				return "", fmt.Errorf("error reading README: %w", err)
			}
			return string(content), nil
		}
	}

	return "", errors.New("README file not found")
}

// GetSetupFiles returns the content of common setup files
func (r *Repository) GetSetupFiles() (map[string]string, error) {
	if !dirExists(r.LocalDir) {
		return nil, errors.New("repository directory does not exist")
	}

	// Common setup files to look for
	setupPatterns := []string{
		// Package managers
		"package.json", "requirements.txt", "Gemfile", "pom.xml", "build.gradle",
		"composer.json", "go.mod", "Cargo.toml", "setup.py",

		// Configuration
		".env.example", "docker-compose.yml", "Dockerfile", "Makefile",

		// Setup scripts
		"install.sh", "setup.sh", "install.bat", "setup.bat",
	}

	result := make(map[string]string)

	for _, pattern := range setupPatterns {
		setupPath := filepath.Join(r.LocalDir, pattern)
		if fileExists(setupPath) {
			content, err := os.ReadFile(setupPath)
			if err != nil {
				continue // Skip files that can't be read
			}
			result[pattern] = string(content)
		}
	}

	return result, nil
}

// GetFiles returns a list of files in the repository
func (r *Repository) GetFiles() ([]string, error) {
	if !dirExists(r.LocalDir) {
		return nil, errors.New("repository directory does not exist")
	}

	var files []string
	err := filepath.Walk(r.LocalDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip .git directory
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}

		// Only include regular files
		if !info.IsDir() {
			relPath, err := filepath.Rel(r.LocalDir, path)
			if err != nil {
				return err
			}
			files = append(files, relPath)
		}
		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("error walking repository: %w", err)
	}

	return files, nil
}

// GetFileContent returns the content of a file in the repository
func (r *Repository) GetFileContent(filePath string) ([]byte, error) {
	fullPath := filepath.Join(r.LocalDir, filePath)
	if !fileExists(fullPath) {
		return nil, fmt.Errorf("file does not exist: %s", filePath)
	}

	content, err := os.ReadFile(fullPath)
	if err != nil {
		return nil, fmt.Errorf("error reading file: %w", err)
	}

	return content, nil
}

// GetRepositoryName extracts the repository name from the URL
func (r *Repository) GetRepositoryName() string {
	// For GitHub URLs like https://github.com/username/repo.git or https://github.com/username/repo
	parts := strings.Split(r.URL, "/")
	if len(parts) > 0 {
		lastPart := parts[len(parts)-1]
		return strings.TrimSuffix(lastPart, ".git")
	}
	return "unknown-repo"
}

// GetAllMarkdownFiles retrieves all markdown files from the repository
func (r *Repository) GetAllMarkdownFiles() (map[string]string, error) {
	markdownFiles := make(map[string]string)
	
	err := filepath.Walk(r.LocalDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		// Skip .git directory
		if info.IsDir() && filepath.Base(path) == ".git" {
			return filepath.SkipDir
		}
		
		// Check if file is markdown
		if !info.IsDir() && (strings.HasSuffix(strings.ToLower(info.Name()), ".md") || 
							 strings.HasSuffix(strings.ToLower(info.Name()), ".markdown")) {
			// Read file content
			content, err := os.ReadFile(path)
			if err != nil {
				return nil // Skip files we can't read
			}
			
			// Store file content with relative path
			relPath, err := filepath.Rel(r.LocalDir, path)
			if err != nil {
				relPath = path // Fallback to full path if we can't get relative path
			}
			
			markdownFiles[relPath] = string(content)
		}
		
		return nil
	})
	
	if err != nil {
		return nil, err
	}
	
	if len(markdownFiles) == 0 {
		return nil, fmt.Errorf("no markdown files found in repository")
	}
	
	return markdownFiles, nil
}

// GetReadmeFiles retrieves README files from the repository
func (r *Repository) GetReadmeFiles() (map[string]string, error) {
	readmeFiles := make(map[string]string)
	
	err := filepath.Walk(r.LocalDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		// Skip .git directory
		if info.IsDir() && filepath.Base(path) == ".git" {
			return filepath.SkipDir
		}
		
		// Check if file is a README
		fileName := strings.ToLower(info.Name())
		if !info.IsDir() && (strings.HasPrefix(fileName, "readme") || 
							 strings.HasPrefix(fileName, "install") || 
							 strings.HasPrefix(fileName, "setup") || 
							 strings.HasPrefix(fileName, "getting-started")) {
			// Read file content
			content, err := os.ReadFile(path)
			if err != nil {
				return nil // Skip files we can't read
			}
			
			// Store file content with relative path
			relPath, err := filepath.Rel(r.LocalDir, path)
			if err != nil {
				relPath = path // Fallback to full path if we can't get relative path
			}
			
			readmeFiles[relPath] = string(content)
		}
		
		return nil
	})
	
	if err != nil {
		return nil, err
	}
	
	if len(readmeFiles) == 0 {
		return nil, fmt.Errorf("no README files found in repository")
	}
	
	return readmeFiles, nil
}

// GetName returns the name of the repository derived from the local directory
func (r *Repository) GetName() string {
	return filepath.Base(r.LocalDir)
}

// Helper function to check if a directory exists and is not empty
func dirExists(path string) bool {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return false
	}
	if !info.IsDir() {
		return false
	}

	// Check if directory is empty
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()

	_, err = f.Readdirnames(1)
	return err == nil
}

// Helper function to check if a file exists
func fileExists(path string) bool {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return false
	}
	return !info.IsDir()
}
