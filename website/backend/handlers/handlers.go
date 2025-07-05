package handlers

import (
	"database/sql"
)

// Base handler types that other handlers will use
type BaseHandler struct {
	DB *sql.DB
}

// Helper function for all handlers
func NewBaseHandler(db *sql.DB) *BaseHandler {
	return &BaseHandler{DB: db}
}
