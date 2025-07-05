package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type ClientHandler struct {
	*BaseHandler
}

func NewClientHandler(db *sql.DB) *ClientHandler {
	return &ClientHandler{BaseHandler: NewBaseHandler(db)}
}

func (h *ClientHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/clients", h.GetClients).Methods("GET")
	r.HandleFunc("/clients/{id}", h.GetClient).Methods("GET")
}

func (h *ClientHandler) GetClients(w http.ResponseWriter, r *http.Request) {
	// Placeholder implementation
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode([]map[string]interface{}{
		{"id": "1", "name": "Acme Corp", "status": "active"},
		{"id": "2", "name": "TechCo", "status": "active"},
	})
}

func (h *ClientHandler) GetClient(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":     id,
		"name":   "Acme Corp",
		"status": "active",
	})
}
