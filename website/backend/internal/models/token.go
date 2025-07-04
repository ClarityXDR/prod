package models

import (
	"crypto/rand"
	"encoding/base64"
	"time"
)

// TokenType represents different types of tokens
type TokenType string

const (
	TokenTypePasswordReset TokenType = "password_reset"
	TokenTypeVerification  TokenType = "verification"
	TokenTypeAPIAccess     TokenType = "api_access"
)

// Token represents a token for various purposes
type Token struct {
	ID        int64     `json:"id"`
	UserID    int64     `json:"user_id"`
	Token     string    `json:"token"`
	Type      TokenType `json:"type"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

// TokenService defines methods for token management
type TokenService interface {
	Create(token *Token) error
	GetByToken(tokenStr string, tokenType TokenType) (*Token, error)
	DeleteByToken(tokenStr string) error
	DeleteExpired() error
	DeleteByUserID(userID int64, tokenType TokenType) error
}

// GenerateToken creates a cryptographically secure random token
func GenerateToken(length int) (string, error) {
	b := make([]byte, length)
	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b), nil
}
