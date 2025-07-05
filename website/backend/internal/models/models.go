package models

import "time"

// User represents a system user
type User struct {
	ID        int64     `json:"id"`
	Email     string    `json:"email"`
	FirstName string    `json:"firstName"`
	LastName  string    `json:"lastName"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// Client represents a client organization
type Client struct {
	ID       int64  `json:"id"`
	ClientID string `json:"clientId"`
	Name     string `json:"name"`
	TenantID string `json:"tenantId"`
	IsActive bool   `json:"isActive"`
}

// License represents a software license
type License struct {
	ID             int64     `json:"id"`
	ClientID       int64     `json:"clientId"`
	LicenseKey     string    `json:"licenseKey"`
	ExpirationDate time.Time `json:"expirationDate"`
	IsActive       bool      `json:"isActive"`
	Features       []string  `json:"features"`
}

// Agent represents an AI agent
type Agent struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Type        string `json:"type"`
	Status      string `json:"status"`
	Description string `json:"description"`
}
