package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type KQLHandler struct {
	*BaseHandler
}

func NewKQLHandler(db *sql.DB) *KQLHandler {
	return &KQLHandler{BaseHandler: NewBaseHandler(db)}
}

func (h *KQLHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/kql/query", h.ExecuteQuery).Methods("POST")
	r.HandleFunc("/kql/history", h.GetHistory).Methods("GET")
}

func (h *KQLHandler) ExecuteQuery(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Query string `json:"query"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Placeholder response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"results": []interface{}{},
	})
}

func (h *KQLHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode([]interface{}{})
}
