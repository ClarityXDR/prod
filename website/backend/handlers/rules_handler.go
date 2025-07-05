package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type RulesHandler struct {
	*BaseHandler
}

func NewRulesHandler(db *sql.DB) *RulesHandler {
	return &RulesHandler{BaseHandler: NewBaseHandler(db)}
}

func (h *RulesHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/rules", h.GetRules).Methods("GET")
	r.HandleFunc("/rules/{id}", h.GetRule).Methods("GET")
}

func (h *RulesHandler) GetRules(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode([]interface{}{})
}

func (h *RulesHandler) GetRule(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":   id,
		"name": "Sample Rule",
	})
}
