package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ClarityXDR/prod/website/backend/config"
	"github.com/ClarityXDR/prod/website/backend/database"
	"github.com/ClarityXDR/prod/website/backend/handlers"
	"github.com/ClarityXDR/prod/website/backend/internal/middleware"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	log.Println("Starting ClarityXDR Backend Server...")

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

	// Add security middleware
	r.Use(middleware.SecurityHeadersMiddleware)
	r.Use(middleware.RateLimitMiddleware)
	r.Use(middleware.LoggingMiddleware)

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

	// License validation endpoint (no auth required for Logic Apps)
	r.HandleFunc("/api/licensing/validate", handlers.NewLicenseHandler(db).ValidateLicense).Methods("GET")

	// Health check endpoint
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy","service":"clarityxdr-backend"}`))
	}).Methods("GET")

	// Serve static files from the React app (if running in production)
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

	// Create HTTP server with timeouts
	srv := &http.Server{
		Addr:         ":" + port,
		WriteTimeout: time.Second * 15,
		ReadTimeout:  time.Second * 15,
		IdleTimeout:  time.Second * 60,
		Handler:      handler,
	}

	// Start the server in a goroutine
	go func() {
		log.Printf("Server starting on port %s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Error starting server: %v", err)
		}
	}()

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	// Create a deadline for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*15)
	defer cancel()

	// Shutdown server
	log.Println("Shutting down server...")
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited properly")
}
