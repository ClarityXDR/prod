package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type AgentHandler struct {
	*BaseHandler
}

func NewAgentHandler(db *sql.DB) *AgentHandler {
	return &AgentHandler{BaseHandler: NewBaseHandler(db)}
}

func (h *AgentHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/agents", h.GetAgents).Methods("GET")
	r.HandleFunc("/agents/{id}", h.GetAgent).Methods("GET")
}

func (h *AgentHandler) GetAgents(w http.ResponseWriter, r *http.Request) {
	// Placeholder implementation
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode([]map[string]interface{}{
		{"id": "1", "name": "Security Agent", "status": "active"},
		{"id": "2", "name": "Sales Agent", "status": "active"},
	})
}

func (h *AgentHandler) GetAgent(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":     id,
		"name":   "Security Agent",
		"status": "active",
	})
}
