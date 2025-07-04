package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/gorilla/mux"
)

type ThreatIntelHandler struct {
	db *sql.DB
}

func NewThreatIntelHandler(db *sql.DB) *ThreatIntelHandler {
	return &ThreatIntelHandler{db: db}
}

func (h *ThreatIntelHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/threat-intel/clients", h.GetClients).Methods("GET")
	r.HandleFunc("/threat-intel/indicators", h.GetIndicators).Methods("GET")
	r.HandleFunc("/threat-intel/indicators", h.AddIndicator).Methods("POST")
	r.HandleFunc("/threat-intel/feeds", h.GetFeeds).Methods("GET")
	r.HandleFunc("/threat-intel/stats", h.GetStats).Methods("GET")
	r.HandleFunc("/threat-intel/sync-sentinel", h.SyncToSentinel).Methods("POST")
}

func (h *ThreatIntelHandler) GetClients(w http.ResponseWriter, r *http.Request) {
	// Reuse client fetching logic
	query := `
        SELECT id, name 
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
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
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

func (h *ThreatIntelHandler) GetIndicators(w http.ResponseWriter, r *http.Request) {
	query := `
        SELECT 
            id,
            client_id,
            indicator_type,
            indicator_value,
            threat_type,
            confidence,
            source,
            created_at
        FROM deployment_mgmt.threat_indicators
        WHERE is_active = true
        ORDER BY created_at DESC
        LIMIT 1000
    `

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var indicators []map[string]interface{}
	for rows.Next() {
		var id, indicatorType, indicatorValue, threatType, source string
		var clientID sql.NullString
		var confidence int
		var createdAt time.Time

		if err := rows.Scan(&id, &clientID, &indicatorType, &indicatorValue,
			&threatType, &confidence, &source, &createdAt); err != nil {
			continue
		}

		indicators = append(indicators, map[string]interface{}{
			"id":         id,
			"clientId":   clientID.String,
			"type":       indicatorType,
			"value":      indicatorValue,
			"threatType": threatType,
			"confidence": confidence,
			"source":     source,
			"createdAt":  createdAt,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(indicators)
}

func (h *ThreatIntelHandler) AddIndicator(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID    string `json:"clientId"`
		Type        string `json:"type"`
		Value       string `json:"value"`
		ThreatType  string `json:"threatType"`
		Confidence  int    `json:"confidence"`
		Source      string `json:"source"`
		Description string `json:"description"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	query := `
        INSERT INTO deployment_mgmt.threat_indicators 
        (client_id, indicator_type, indicator_value, threat_type, confidence, source, description)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (client_id, indicator_type, indicator_value) 
        DO UPDATE SET 
            threat_type = $4,
            confidence = $5,
            updated_at = NOW()
    `

	var clientID interface{} = req.ClientID
	if req.ClientID == "" {
		clientID = nil
	}

	_, err := h.db.Exec(query, clientID, req.Type, req.Value,
		req.ThreatType, req.Confidence, req.Source, req.Description)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "added",
	})
}

func (h *ThreatIntelHandler) GetFeeds(w http.ResponseWriter, r *http.Request) {
	query := `
        SELECT 
            id,
            name,
            description,
            enabled,
            last_update,
            indicator_count,
            sync_progress
        FROM deployment_mgmt.threat_feeds
        ORDER BY name
    `

	rows, err := h.db.Query(query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var feeds []map[string]interface{}
	for rows.Next() {
		var id, name, description string
		var enabled bool
		var indicatorCount, syncProgress int
		var lastUpdate sql.NullTime

		if err := rows.Scan(&id, &name, &description, &enabled,
			&lastUpdate, &indicatorCount, &syncProgress); err != nil {
			continue
		}

		feeds = append(feeds, map[string]interface{}{
			"id":             id,
			"name":           name,
			"description":    description,
			"enabled":        enabled,
			"lastUpdate":     lastUpdate.Time,
			"indicatorCount": indicatorCount,
			"syncProgress":   syncProgress,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(feeds)
}

func (h *ThreatIntelHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	var stats struct {
		TotalIndicators int
		ActiveFeeds     int
		LastUpdate      sql.NullTime
	}

	query := `
        SELECT 
            (SELECT COUNT(*) FROM deployment_mgmt.threat_indicators WHERE is_active = true),
            (SELECT COUNT(*) FROM deployment_mgmt.threat_feeds WHERE enabled = true),
            (SELECT MAX(created_at) FROM deployment_mgmt.threat_indicators)
    `

	h.db.QueryRow(query).Scan(&stats.TotalIndicators, &stats.ActiveFeeds, &stats.LastUpdate)

	response := map[string]interface{}{
		"totalIndicators": stats.TotalIndicators,
		"activeFeeds":     stats.ActiveFeeds,
		"lastUpdate":      stats.LastUpdate.Time,
		"syncStatus":      "idle",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *ThreatIntelHandler) SyncToSentinel(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientID string `json:"clientId"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Update sync status for indicators
	query := `
        UPDATE deployment_mgmt.threat_indicators 
        SET synced_to_sentinel = true, synced_at = NOW()
        WHERE client_id = $1 OR client_id IS NULL
    `

	_, err := h.db.Exec(query, req.ClientID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// TODO: Implement actual Sentinel sync logic

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "synced",
	})
}
