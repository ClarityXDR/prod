package main

import (
	"log"
	"net/http"
	"os"

	"clarityxdr/backend/config"
	"clarityxdr/backend/database"
	"clarityxdr/backend/handlers"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize database
	db, err := database.Initialize(cfg.DatabaseURL)
	if err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer db.Close()

	// Create router
	r := mux.NewRouter()

	// Initialize handlers
	agentHandler := handlers.NewAgentHandler(db)
	kqlHandler := handlers.NewKQLHandler(db)
	clientHandler := handlers.NewClientHandler(db)
	rulesHandler := handlers.NewRulesHandler(db)
	licenseHandler := handlers.NewLicenseHandler(db)
	logicAppHandler := handlers.NewLogicAppHandler(db)
	mdeHandler := handlers.NewMDEHandler(db)
	threatIntelHandler := handlers.NewThreatIntelHandler(db)
	sentinelHandler := handlers.NewSentinelHandler(db)

	// Register routes
	api := r.PathPrefix("/api").Subrouter()
	agentHandler.RegisterRoutes(api)
	kqlHandler.RegisterRoutes(api)
	clientHandler.RegisterRoutes(api)
	rulesHandler.RegisterRoutes(api)
	licenseHandler.RegisterRoutes(api)
	logicAppHandler.RegisterRoutes(api)
	mdeHandler.RegisterRoutes(api)
	threatIntelHandler.RegisterRoutes(api)
	sentinelHandler.RegisterRoutes(api)

	// Static file serving for the React app
	r.PathPrefix("/").Handler(http.FileServer(http.Dir("./frontend/build/")))

	// Setup CORS
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000", "http://localhost:8080"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})

	handler := c.Handler(r)

	// Get port from environment or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}
