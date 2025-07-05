package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type SentinelHandler struct {
	*BaseHandler
}

func NewSentinelHandler(db *sql.DB) *SentinelHandler {
	return &SentinelHandler{BaseHandler: NewBaseHandler(db)}
}

func (h *SentinelHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/sentinel/workspaces", h.GetWorkspaces).Methods("GET")
	r.HandleFunc("/sentinel/incidents", h.GetIncidents).Methods("GET")
}

func (h *SentinelHandler) GetWorkspaces(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode([]interface{}{})
}

func (h *SentinelHandler) GetIncidents(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode([]interface{}{})
}
