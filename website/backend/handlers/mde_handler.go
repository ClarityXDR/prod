package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
)

type MDEHandler struct {
	db *sql.DB
}

func NewMDEHandler(db *sql.DB) *MDEHandler {
	return &MDEHandler{db: db}
}

func (h *MDEHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/mde/clients", h.GetClients).Methods("GET")
	r.HandleFunc("/mde/rules/templates", h.GetRuleTemplates).Methods("GET")
	r.HandleFunc("/mde/rules/deployed", h.GetDeployedRules).Methods("GET")
	r.HandleFunc("/mde/rules/deploy", h.DeployRule).Methods("POST")
	r.HandleFunc("/mde/rules/create", h.CreateCustomRule).Methods("POST")
}

func (h *MDEHandler) GetClients(w http.ResponseWriter, r *http.Request) {
	// Reuse logic from LogicAppHandler.GetClients
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

func (h *MDEHandler) GetRuleTemplates(w http.ResponseWriter, r *http.Request) {
	query := `
        SELECT id, title, description, severity, category, kql_query
        FROM mde_rules.master_rules
        WHERE is_active = true
        ORDER BY title
    `

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var rules []map[string]interface{}
	for rows.Next() {
		var id, title, description, severity, category, kqlQuery string
		if err := rows.Scan(&id, &title, &description, &severity, &category, &kqlQuery); err != nil {
			continue
		}
		rules = append(rules, map[string]interface{}{
			"id":          id,
			"title":       title,
			"description": description,
			"severity":    severity,
			"category":    category,
			"kqlQuery":    kqlQuery,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rules)
}

func (h *MDEHandler) GetDeployedRules(w http.ResponseWriter, r *http.Request) {
	query := `
        SELECT 
            d.id,
            d.client_id,
            c.name as client_name,
            r.title,
            r.severity,
            d.enabled,
            d.deployed_at
        FROM deployment_mgmt.mde_rule_deployments d
        JOIN client_mgmt.clients c ON d.client_id = c.id
        JOIN mde_rules.master_rules r ON d.rule_id = r.id
        WHERE d.deployment_status = 'deployed'
        ORDER BY d.deployed_at DESC
    `

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var deployedRules []map[string]interface{}
	for rows.Next() {
		var id, clientID, clientName, title, severity string
		var enabled bool
		var deployedAt sql.NullTime

		if err := rows.Scan(&id, &clientID, &clientName, &title, &severity, &enabled, &deployedAt); err != nil {
			continue
		}

		deployedRules = append(deployedRules, map[string]interface{}{
			"id":         id,
			"clientId":   clientID,
			"clientName": clientName,
			"title":      title,
			"severity":   severity,
			"enabled":    enabled,
			"deployedAt": deployedAt.Time,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(deployedRules)
}

func (h *MDEHandler) DeployRule(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID       string                 `json:"clientId"`
		RuleID         string                 `json:"ruleId"`
		Customizations map[string]interface{} `json:"customizations"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	customizationsJSON, _ := json.Marshal(req.Customizations)

	query := `
        INSERT INTO deployment_mgmt.mde_rule_deployments 
        (client_id, rule_id, deployment_status, enabled, customizations, deployed_at)
        VALUES ($1, $2, 'deployed', true, $3, NOW())
        ON CONFLICT (client_id, rule_id) 
        DO UPDATE SET 
            deployment_status = 'deployed',
            enabled = true,
            customizations = $3,
            updated_at = NOW()
    `

	_, err := h.db.Exec(query, req.ClientID, req.RuleID, customizationsJSON)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "deployed",
	})
}

func (h *MDEHandler) CreateCustomRule(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID    string `json:"clientId"`
		Title       string `json:"title"`
		Description string `json:"description"`
		Severity    string `json:"severity"`
		Category    string `json:"category"`
		KQLQuery    string `json:"kqlQuery"`
		Enabled     bool   `json:"enabled"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Create custom rule (simplified - would normally create in master_rules first)
	query := `
        INSERT INTO mde_rules.master_rules 
        (title, description, severity, category, kql_query, is_active)
        VALUES ($1, $2, $3, $4, $5, true)
        RETURNING id
    `

	var ruleID string
	err := h.db.QueryRow(query, req.Title, req.Description, req.Severity,
		req.Category, req.KQLQuery).Scan(&ruleID)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"ruleId": ruleID,
		"status": "created",
	})
}
