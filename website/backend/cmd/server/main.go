package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ClarityXDR/backend/internal/db"
	"github.com/ClarityXDR/backend/internal/handlers"
	"github.com/ClarityXDR/backend/internal/middleware"
	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	log.Println("Starting ClarityXDR Backend Server...")

	// Initialize database connection
	database, err := db.NewDatabase()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	// Create router and set up routes
	r := mux.NewRouter()

	// Add security middleware
	r.Use(middleware.SecurityHeadersMiddleware)
	r.Use(middleware.RateLimitMiddleware)
	r.Use(middleware.LoggingMiddleware)

	// Configure CORS properly
	c := cors.New(cors.Options{
		AllowedOrigins: []string{
			os.Getenv("FRONTEND_URL"),
			"https://" + os.Getenv("DOMAIN_NAME"),
			"https://api." + os.Getenv("DOMAIN_NAME"),
		},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization", "X-Requested-With"},
		ExposedHeaders:   []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           86400,
	})

	// API routes with authentication
	apiRouter := r.PathPrefix("/api").Subrouter()
	apiRouter.Use(middleware.AuthMiddleware)

	// Register handlers
	handlers.RegisterRoutes(apiRouter, database)

	// License validation endpoint (no auth required for Logic Apps)
	r.HandleFunc("/api/licensing/validate", handlers.NewLicenseHandler(database).ValidateLicense).Methods("GET")

	// Health check endpoint
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy","service":"clarityxdr-backend"}`))
	}).Methods("GET")

	// Serve static files from the React app (if running in production)
	staticDir := os.Getenv("STATIC_DIR")
	if staticDir != "" {
		r.PathPrefix("/").Handler(http.FileServer(http.Dir(staticDir)))
	}

	// Apply CORS
	handler := c.Handler(r)

	// Create HTTP server with timeouts
	srv := &http.Server{
		Addr:         ":8080",
		WriteTimeout: time.Second * 15,
		ReadTimeout:  time.Second * 15,
		IdleTimeout:  time.Second * 60,
		Handler:      handler,
	}

	// Start the server in a goroutine
	go func() {
		log.Println("Server starting on :8080")
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
