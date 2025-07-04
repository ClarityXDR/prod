package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/ClarityXDR/backend/internal/db"
	"github.com/gorilla/mux"
)

type MDEHandler struct {
	db *db.Database
}

func NewMDEHandler(database *db.Database) *MDEHandler {
	return &MDEHandler{
		db: database,
	}
}

type MDERuleTemplate struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Severity    string `json:"severity"`
	Category    string `json:"category"`
	KQLQuery    string `json:"kqlQuery"`
}

type MDEDeploymentRequest struct {
	ClientID       string `json:"clientId"`
	RuleID         string `json:"ruleId"`
	Customizations map[string]interface{} `json:"customizations"`
}

func (h *MDEHandler) GetClients(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement get clients functionality
	clients := []map[string]interface{}{
		{"clientId": "demo-client-1", "name": "Demo Company Inc."},
	}
	respondWithJSON(w, http.StatusOK, clients)
}

func (h *MDEHandler) GetRuleTemplates(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement get rule templates from database
	templates := []MDERuleTemplate{
		{
			ID: "rule-1",
			Title: "Suspicious PowerShell Execution",
			Description: "Detects suspicious PowerShell command execution patterns",
			Severity: "high",
			Category: "Execution",
			KQLQuery: "DeviceProcessEvents | where FileName =~ 'powershell.exe' | where ProcessCommandLine contains '-enc'",
		},
	}
	respondWithJSON(w, http.StatusOK, templates)
}

func (h *MDEHandler) GetDeployedRules(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement get deployed rules from database
	deployedRules := []map[string]interface{}{
		{
			"id": "deployed-1",
			"clientId": "demo-client-1",
			"clientName": "Demo Company Inc.",
			"title": "Suspicious PowerShell Execution",
			"severity": "high",
			"enabled": true,
			"deployedAt": "2025-01-04T00:00:00Z",
		},
	}
	respondWithJSON(w, http.StatusOK, deployedRules)
}

func (h *MDEHandler) DeployRule(w http.ResponseWriter, r *http.Request) {
	var req MDEDeploymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// TODO: Implement rule deployment logic
	respondWithJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Rule deployed successfully",
	})
}

func (h *MDEHandler) CreateCustomRule(w http.ResponseWriter, r *http.Request) {
	var rule MDERuleTemplate
	if err := json.NewDecoder(r.Body).Decode(&rule); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// TODO: Implement custom rule creation
	respondWithJSON(w, http.StatusCreated, map[string]interface{}{
		"success": true,
		"message": "Custom rule created successfully",
		"ruleId": "new-rule-id",
	})
}

func (h *MDEHandler) RegisterRoutes(router *mux.Router) {
	router.HandleFunc("/mde/clients", h.GetClients).Methods("GET")
	router.HandleFunc("/mde/rules/templates", h.GetRuleTemplates).Methods("GET")
	router.HandleFunc("/mde/rules/deployed", h.GetDeployedRules).Methods("GET")
	router.HandleFunc("/mde/rules/deploy", h.DeployRule).Methods("POST")
	router.HandleFunc("/mde/rules/create", h.CreateCustomRule).Methods("POST")
}
