package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"time"

	"github.com/ClarityXDR/prod/website/backend/internal/db"
	"github.com/gorilla/mux"
	"github.com/lib/pq"
)

type LicenseHandler struct {
	db *db.Database
}

func NewLicenseHandler(database *db.Database) *LicenseHandler {
	return &LicenseHandler{db: database}
}

type LicenseValidationRequest struct {
	LicenseKey  string `json:"license_key"`
	ClientID    string `json:"client_id"`
	ProductName string `json:"product_name"`
}

type LicenseValidationResponse struct {
	Valid          bool     `json:"valid"`
	ExpirationDate string   `json:"expirationDate,omitempty"`
	Features       []string `json:"features,omitempty"`
	Message        string   `json:"message"`
}

func (h *LicenseHandler) ValidateLicense(w http.ResponseWriter, r *http.Request) {
	licenseKey := r.Header.Get("x-license-key")
	clientID := r.Header.Get("x-client-id")
	productName := r.Header.Get("x-product-name")

	if licenseKey == "" || clientID == "" {
		respondWithJSON(w, http.StatusBadRequest, LicenseValidationResponse{
			Valid:   false,
			Message: "License key and client ID are required",
		})
		return
	}

	// Validate license against database
	query := `
		SELECT l.id, l.expiration_date, l.is_active, l.features
		FROM licenses l
		JOIN clients c ON l.client_id = c.id
		WHERE l.license_key = $1 AND c.client_id = $2
	`

	var licenseID int
	var expirationDate time.Time
	var isActive bool
	var features []string

	err := h.db.DB.QueryRow(query, licenseKey, clientID).Scan(&licenseID, &expirationDate, &isActive, pq.Array(&features))
	if err != nil {
		respondWithJSON(w, http.StatusOK, LicenseValidationResponse{
			Valid:   false,
			Message: "Invalid license key",
		})
		return
	}

	// Check if license is active
	if !isActive {
		respondWithJSON(w, http.StatusOK, LicenseValidationResponse{
			Valid:          false,
			ExpirationDate: expirationDate.Format(time.RFC3339),
			Message:        "License has been deactivated",
		})
		return
	}

	// Check if license is expired
	if expirationDate.Before(time.Now()) {
		respondWithJSON(w, http.StatusOK, LicenseValidationResponse{
			Valid:          false,
			ExpirationDate: expirationDate.Format(time.RFC3339),
			Message:        "License has expired",
		})
		return
	}

	// Log the license check
	_, err = h.db.DB.Exec(`
		INSERT INTO license_checks (license_id, checked_at, product, ip_address)
		VALUES ($1, $2, $3, $4)
	`, licenseID, time.Now(), productName, r.RemoteAddr)

	if err != nil {
		// Log error but don't fail the validation
		// License is still valid even if we can't log the check
		// You might want to add proper logging here
	}

	// Return success response
	respondWithJSON(w, http.StatusOK, LicenseValidationResponse{
		Valid:          true,
		ExpirationDate: expirationDate.Format(time.RFC3339),
		Features:       features,
		Message:        "License is valid",
	})
}

func (h *LicenseHandler) CreateLicense(w http.ResponseWriter, r *http.Request) {
	// Require authentication
	if !isAuthenticated(r) {
		respondWithError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req struct {
		ClientID       string   `json:"client_id"`
		ExpirationDate string   `json:"expiration_date"`
		Features       []string `json:"features"`
		Notes          string   `json:"notes"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate input
	if req.ClientID == "" || req.ExpirationDate == "" {
		respondWithError(w, http.StatusBadRequest, "Missing required fields")
		return
	}

	// Generate secure license key
	licenseKey := generateLicenseKey()

	// Parse expiration date
	expirationDate, err := time.Parse("2006-01-02", req.ExpirationDate)
	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid expiration date format")
		return
	}

	// Get client ID from database
	var clientDBID int
	err = h.db.DB.QueryRow("SELECT id FROM clients WHERE client_id = $1", req.ClientID).Scan(&clientDBID)
	if err != nil {
		respondWithError(w, http.StatusNotFound, "Client not found")
		return
	}

	// Insert license
	var licenseID int
	err = h.db.DB.QueryRow(`
		INSERT INTO licenses (client_id, license_key, issue_date, expiration_date, is_active, features, notes)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id
	`, clientDBID, licenseKey, time.Now(), expirationDate, true, pq.Array(req.Features), req.Notes).Scan(&licenseID)

	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to create license")
		return
	}

	respondWithJSON(w, http.StatusCreated, map[string]interface{}{
		"id":              licenseID,
		"license_key":     licenseKey,
		"expiration_date": expirationDate.Format("2006-01-02"),
	})
}

func generateLicenseKey() string {
	bytes := make([]byte, 16)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

func (h *LicenseHandler) RegisterRoutes(router *mux.Router) {
	router.HandleFunc("/licensing/validate", h.ValidateLicense).Methods("GET")
	router.HandleFunc("/licensing/licenses", h.CreateLicense).Methods("POST")
	// ...existing code...
}

// Helper functions that were missing
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, map[string]string{"error": message})
}

func isAuthenticated(r *http.Request) bool {
	// Check if the request has valid authentication
	// This should match your authentication middleware
	userID := r.Context().Value("userID")
	return userID != nil
}
