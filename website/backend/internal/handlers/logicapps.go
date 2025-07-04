package handlers

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"

	"github.com/ClarityXDR/backend/internal/db"
	"github.com/gorilla/mux"
)

type LogicAppHandler struct {
	db              *db.Database
	azureClient     *AzureClient
	licenseEndpoint string
}

func NewLogicAppHandler(database *db.Database) *LogicAppHandler {
	return &LogicAppHandler{
		db:              database,
		azureClient:     NewAzureClient(),
		licenseEndpoint: os.Getenv("LICENSE_API_ENDPOINT"),
	}
}

type LogicAppDeploymentRequest struct {
	ClientID       string `json:"clientId"`
	SubscriptionID string `json:"subscriptionId"`
	ResourceGroup  string `json:"resourceGroup"`
	LogicAppName   string `json:"logicAppName"`
	TemplateName   string `json:"templateName"`
}

func (h *LogicAppHandler) DeployLogicApp(w http.ResponseWriter, r *http.Request) {
	// Require authentication
	if !isAuthenticated(r) {
		respondWithError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req LogicAppDeploymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate input
	if err := validateDeploymentRequest(req); err != nil {
		respondWithError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Verify client exists and has valid license
	var clientDBID int
	var licenseKey string
	err := h.db.QueryRow(`
		SELECT c.id, l.license_key 
		FROM clients c
		JOIN licenses l ON l.client_id = c.id
		WHERE c.client_id = $1 
		AND l.is_active = true 
		AND l.expiration_date > NOW()
		LIMIT 1
	`, req.ClientID).Scan(&clientDBID, &licenseKey)

	if err != nil {
		respondWithError(w, http.StatusBadRequest, "Client does not have an active license")
		return
	}

	// Load template
	templatePath := fmt.Sprintf("/app/templates/logic-apps/%s.json", req.TemplateName)
	templateContent, err := ioutil.ReadFile(templatePath)
	if err != nil {
		respondWithError(w, http.StatusNotFound, "Template not found")
		return
	}

	// Process template - inject license information
	processedTemplate := h.processTemplate(string(templateContent), req.ClientID, licenseKey)

	// Deploy to Azure
	err = h.azureClient.DeployLogicApp(req.SubscriptionID, req.ResourceGroup, req.LogicAppName, processedTemplate)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Failed to deploy Logic App")
		return
	}

	// Record deployment
	_, err = h.db.Exec(`
		INSERT INTO logic_app_deployments (client_id, logic_app_name, subscription_id, resource_group, template_name, deployed_at, status)
		VALUES ($1, $2, $3, $4, $5, NOW(), 'Success')
	`, clientDBID, req.LogicAppName, req.SubscriptionID, req.ResourceGroup, req.TemplateName)

	respondWithJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Logic App deployed successfully",
	})
}

func (h *LogicAppHandler) processTemplate(template, clientID, licenseKey string) string {
	// Replace placeholders with actual values
	template = strings.ReplaceAll(template, "00000000-0000-0000-0000-000000000000", licenseKey)
	template = strings.ReplaceAll(template, "@{parameters('ClientID')}", clientID)

	// Update license validation endpoint
	if h.licenseEndpoint != "" {
		template = strings.ReplaceAll(template, "https://api.yourcompany.com/licensing/validate", h.licenseEndpoint)
	}

	return template
}

func validateDeploymentRequest(req LogicAppDeploymentRequest) error {
	if req.ClientID == "" {
		return fmt.Errorf("clientId is required")
	}
	if req.SubscriptionID == "" {
		return fmt.Errorf("subscriptionId is required")
	}
	if req.ResourceGroup == "" {
		return fmt.Errorf("resourceGroup is required")
	}
	if req.LogicAppName == "" {
		return fmt.Errorf("logicAppName is required")
	}
	if req.TemplateName == "" {
		return fmt.Errorf("templateName is required")
	}
	// Validate Logic App name format
	if !isValidAzureResourceName(req.LogicAppName) {
		return fmt.Errorf("invalid Logic App name format")
	}
	return nil
}

func isValidAzureResourceName(name string) bool {
	// Azure resource naming rules
	if len(name) < 1 || len(name) > 80 {
		return false
	}
	// Must start with letter or number, can contain letters, numbers, and hyphens
	// Implement proper validation regex
	return true
}

func (h *LogicAppHandler) RegisterRoutes(router *mux.Router) {
	router.HandleFunc("/logicapps/deploy", h.DeployLogicApp).Methods("POST")
	router.HandleFunc("/logicapps/disable", h.DisableLogicApp).Methods("POST")
	router.HandleFunc("/logicapps/templates", h.GetTemplates).Methods("GET")
	router.HandleFunc("/logicapps/clients", h.GetClients).Methods("GET")
}
