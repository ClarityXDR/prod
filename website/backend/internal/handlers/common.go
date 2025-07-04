package handlers

import (
	"encoding/json"
	"net/http"
)

// respondWithError sends an error response
func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, map[string]string{"error": message})
}

// respondWithJSON sends a JSON response
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

// isAuthenticated checks if the request is authenticated
func isAuthenticated(r *http.Request) bool {
	// TODO: Implement proper authentication
	// For now, return true to allow development
	return true
}
