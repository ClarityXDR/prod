package git

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Repository manages Git repositories
type Repository struct {
	ID          int64
	Name        string
	Description string
	Path        string
	IsPrivate   bool
	OwnerID     int64
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// GitService defines methods for Git repository management
type GitService interface {
	CreateRepository(name, description string, ownerID int64, isPrivate bool) (*Repository, error)
	CloneRepository(url, name string, ownerID int64, isPrivate bool) (*Repository, error)
	GetRepository(id int64) (*Repository, error)
	ListRepositories(ownerID int64) ([]*Repository, error)
	DeleteRepository(id int64) error
	PushChanges(repoID int64, message string) error
	PullChanges(repoID int64) error
	GetCommitHistory(repoID int64, limit int) ([]Commit, error)
}

// Commit represents a Git commit
type Commit struct {
	Hash      string
	Author    string
	Email     string
	Message   string
	Date      time.Time
	FileCount int
}

// GitManager implements GitService
type GitManager struct {
	baseDir       string
	db            interface{} // Database connection
	currentUserID int64       // User performing the action
}

// NewGitManager creates a new GitManager
func NewGitManager(baseDir string, db interface{}, userID int64) *GitManager {
	return &GitManager{
		baseDir:       baseDir,
		db:            db,
		currentUserID: userID,
	}
}

// CreateRepository creates a new Git repository
func (g *GitManager) CreateRepository(name, description string, ownerID int64, isPrivate bool) (*Repository, error) {
	// Validate repository name
	if !isValidRepoName(name) {
		return nil, fmt.Errorf("invalid repository name: %s", name)
	}

	// Create repository path
	repoPath := filepath.Join(g.baseDir, fmt.Sprintf("%d", ownerID), name)

	// Check if repo exists
	if _, err := os.Stat(repoPath); err == nil {
		return nil, fmt.Errorf("repository %s already exists", name)
	}

	// Create directory structure
	if err := os.MkdirAll(repoPath, 0755); err != nil {
		return nil, err
	}

	// Initialize Git repository
	cmd := exec.Command("git", "init", "--bare")
	cmd.Dir = repoPath
	if output, err := cmd.CombinedOutput(); err != nil {
		log.Printf("Git init error: %s", output)
		return nil, err
	}

	// Create repository in database
	// (Here you would use the database to store the repository metadata)
	repo := &Repository{
		Name:        name,
		Description: description,
		Path:        repoPath,
		IsPrivate:   isPrivate,
		OwnerID:     ownerID,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// Return the created repository
	return repo, nil
}

// CloneRepository clones an existing Git repository
func (g *GitManager) CloneRepository(url, name string, ownerID int64, isPrivate bool) (*Repository, error) {
	// Validate repository name
	if !isValidRepoName(name) {
		return nil, fmt.Errorf("invalid repository name: %s", name)
	}

	// Create repository path
	repoPath := filepath.Join(g.baseDir, fmt.Sprintf("%d", ownerID), name)

	// Check if repo exists
	if _, err := os.Stat(repoPath); err == nil {
		return nil, fmt.Errorf("repository %s already exists", name)
	}

	// Create parent directory
	parentDir := filepath.Dir(repoPath)
	if err := os.MkdirAll(parentDir, 0755); err != nil {
		return nil, err
	}

	// Clone the repository
	cmd := exec.Command("git", "clone", "--mirror", url, repoPath)
	if output, err := cmd.CombinedOutput(); err != nil {
		log.Printf("Git clone error: %s", output)
		return nil, err
	}

	// Create repository in database
	repo := &Repository{
		Name:        name,
		Description: fmt.Sprintf("Cloned from %s", url),
		Path:        repoPath,
		IsPrivate:   isPrivate,
		OwnerID:     ownerID,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// Return the cloned repository
	return repo, nil
}

// isValidRepoName checks if a repository name is valid
func isValidRepoName(name string) bool {
	// Only allow alphanumeric, dash, and underscore
	if len(name) == 0 || len(name) > 100 {
		return false
	}

	// Check for valid characters
	for _, c := range name {
		if !((c >= 'a' && c <= 'z') ||
			(c >= 'A' && c <= 'Z') ||
			(c >= '0' && c <= '9') ||
			c == '-' || c == '_' || c == '.') {
			return false
		}
	}

	// Must not end with .git
	if strings.HasSuffix(name, ".git") {
		return false
	}

	return true
}
