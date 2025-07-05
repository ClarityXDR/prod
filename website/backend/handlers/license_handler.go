package handlers

import (
	"database/sql"
)

type LicenseHandler struct {
	db *sql.DB
}

func NewLicenseHandler(database *sql.DB) *LicenseHandler {
	return &LicenseHandler{db: database}
}

// ...existing code from internal/handlers/license.go...
