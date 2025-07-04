package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type SentinelHandler struct {
	db *sql.DB
}

func NewSentinelHandler(db *sql.DB) *SentinelHandler {
	return &SentinelHandler{db: db}
}

func (h *SentinelHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/sentinel/clients", h.GetClients).Methods("GET")
	r.HandleFunc("/sentinel/validate", h.ValidateConfig).Methods("POST")
	r.HandleFunc("/sentinel/deploy", h.Deploy).Methods("POST")
}

func (h *SentinelHandler) GetClients(w http.ResponseWriter, r *http.Request) {
	// Reuse client fetching logic
	query := `
        SELECT id, name, tenant_id 
        FROM client_mgmt.clients 
        WHERE is_active = true
        ORDER BY name
    `

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var clients []map[string]interface{}
	for rows.Next() {
		var id, name, tenantID string
		if err := rows.Scan(&id, &name, &tenantID); err != nil {
			continue
		}
		clients = append(clients, map[string]interface{}{
			"clientId": id,
			"name":     name,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(clients)
}

func (h *SentinelHandler) ValidateConfig(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID string                 `json:"clientId"`
		Config   map[string]interface{} `json:"config"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Basic validation
	valid := true
	message := ""

	if req.ClientID == "" {
		valid = false
		message = "Client ID is required"
	}

	if config, ok := req.Config["workspaceName"].(string); !ok || config == "" {
		valid = false
		message = "Workspace name is required"
	}

	response := map[string]interface{}{
		"valid":   valid,
		"message": message,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *SentinelHandler) Deploy(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID string                 `json:"clientId"`
		Config   map[string]interface{} `json:"config"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	configJSON, _ := json.Marshal(req.Config)

	// Insert deployment record
	query := `
        INSERT INTO deployment_mgmt.sentinel_deployments 
        (client_id, workspace_name, subscription_id, resource_group, location, configuration, deployment_status)
        VALUES ($1, $2, $3, $4, $5, $6, 'pending')
        RETURNING id
    `

	var deploymentID string
	err := h.db.QueryRow(query,
		req.ClientID,
		req.Config["workspaceName"],
		req.Config["subscriptionId"],
		req.Config["resourceGroup"],
		req.Config["location"],
		configJSON,
	).Scan(&deploymentID)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// TODO: Trigger actual Azure Sentinel deployment

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"deploymentId": deploymentID,
		"status":       "initiated",
	})
}
