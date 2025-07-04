package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type LogicAppHandler struct {
	db *sql.DB
}

func NewLogicAppHandler(db *sql.DB) *LogicAppHandler {
	return &LogicAppHandler{db: db}
}

func (h *LogicAppHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/logicapps/clients", h.GetClients).Methods("GET")
	r.HandleFunc("/logicapps/templates", h.GetTemplates).Methods("GET")
	r.HandleFunc("/logicapps/deployments", h.GetDeployments).Methods("GET")
	r.HandleFunc("/logicapps/deploy", h.DeployLogicApp).Methods("POST")
	r.HandleFunc("/logicapps/disable", h.DisableLogicApp).Methods("POST")
}

func (h *LogicAppHandler) GetClients(w http.ResponseWriter, r *http.Request) {
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
			"tenantId": tenantID,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(clients)
}

func (h *LogicAppHandler) GetTemplates(w http.ResponseWriter, r *http.Request) {
	templates := []map[string]interface{}{
		{
			"name":        "sentinel-integration",
			"displayName": "Sentinel Integration",
			"description": "Integrates ClarityXDR with Microsoft Sentinel",
		},
		{
			"name":        "incident-response",
			"displayName": "Incident Response",
			"description": "Automated incident response workflows",
		},
		{
			"name":        "threat-hunting",
			"displayName": "Threat Hunting",
			"description": "Automated threat hunting and investigation",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(templates)
}

func (h *LogicAppHandler) GetDeployments(w http.ResponseWriter, r *http.Request) {
	query := `
        SELECT 
            d.id,
            d.logic_app_name,
            d.template_name,
            d.resource_group,
            d.status,
            d.deployed_at,
            c.name as client_name,
            c.id as client_id
        FROM deployment_mgmt.logic_app_deployments d
        JOIN client_mgmt.clients c ON d.client_id = c.id
        ORDER BY d.deployed_at DESC
        LIMIT 100
    `

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var deployments []map[string]interface{}
	for rows.Next() {
		var dep struct {
			ID            string
			LogicAppName  string
			TemplateName  string
			ResourceGroup string
			Status        string
			DeployedAt    sql.NullTime
			ClientName    string
			ClientID      string
		}

		if err := rows.Scan(&dep.ID, &dep.LogicAppName, &dep.TemplateName,
			&dep.ResourceGroup, &dep.Status, &dep.DeployedAt,
			&dep.ClientName, &dep.ClientID); err != nil {
			continue
		}

		deployments = append(deployments, map[string]interface{}{
			"id":            dep.ID,
			"logicAppName":  dep.LogicAppName,
			"templateName":  dep.TemplateName,
			"resourceGroup": dep.ResourceGroup,
			"status":        dep.Status,
			"deployedAt":    dep.DeployedAt.Time,
			"clientName":    dep.ClientName,
			"clientId":      dep.ClientID,
		})
	}

	// Calculate stats
	statsQuery := `
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'Active') as active,
            COUNT(*) FILTER (WHERE status = 'Failed') as failed,
            COUNT(*) FILTER (WHERE status = 'Pending') as pending
        FROM deployment_mgmt.logic_app_deployments
    `

	var stats struct {
		Total   int
		Active  int
		Failed  int
		Pending int
	}

	h.db.QueryRow(statsQuery).Scan(&stats.Total, &stats.Active, &stats.Failed, &stats.Pending)

	response := map[string]interface{}{
		"deployments": deployments,
		"stats": map[string]int{
			"total":   stats.Total,
			"active":  stats.Active,
			"failed":  stats.Failed,
			"pending": stats.Pending,
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *LogicAppHandler) DeployLogicApp(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID         string `json:"clientId"`
		TemplateName     string `json:"templateName"`
		LogicAppName     string `json:"logicAppName"`
		SubscriptionID   string `json:"subscriptionId"`
		ResourceGroup    string `json:"resourceGroup"`
		AzureCredentials struct {
			TenantID     string `json:"tenantId"`
			ClientID     string `json:"clientId"`
			ClientSecret string `json:"clientSecret"`
		} `json:"azureCredentials,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Insert deployment record
	query := `
        INSERT INTO deployment_mgmt.logic_app_deployments 
        (client_id, logic_app_name, subscription_id, resource_group, template_name, status)
        VALUES ($1, $2, $3, $4, $5, 'Pending')
        RETURNING id
    `

	var deploymentID string
	err := h.db.QueryRow(query, req.ClientID, req.LogicAppName,
		req.SubscriptionID, req.ResourceGroup, req.TemplateName).Scan(&deploymentID)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// TODO: Trigger actual Azure deployment here

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"deploymentId": deploymentID,
		"status":       "initiated",
	})
}

func (h *LogicAppHandler) DisableLogicApp(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID       string `json:"clientId"`
		SubscriptionID string `json:"subscriptionId"`
		ResourceGroup  string `json:"resourceGroup"`
		LogicAppName   string `json:"logicAppName"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Update deployment status
	query := `
        UPDATE deployment_mgmt.logic_app_deployments 
        SET status = 'Disabled', updated_at = NOW()
        WHERE client_id = $1 AND logic_app_name = $2
    `

	_, err := h.db.Exec(query, req.ClientID, req.LogicAppName)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// TODO: Trigger actual Azure disable operation here

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "disabled",
	})
}
