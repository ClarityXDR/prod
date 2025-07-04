package db

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"database/sql"
	"fmt"
	"io"
	"log"
	"os"

	_ "github.com/lib/pq"
)

// Database represents a connection to the database
type Database struct {
	DB  *sql.DB
	gcm cipher.AEAD // For data encryption
}

// NewDatabase creates a new database connection
func NewDatabase() (*Database, error) {
	// Get connection details from environment variables
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPassword := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "clarityxdr")
	sslMode := getEnv("DB_SSL_MODE", "disable")

	// Create connection string
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPassword, dbName, sslMode)

	// Open connection
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %v", err)
	}

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}

	log.Println("Successfully connected to database")

	// Initialize encryption
	encryptionKey := getEnv("ENCRYPTION_KEY", "")
	var gcm cipher.AEAD

	if encryptionKey != "" {
		// Ensure key is 32 bytes for AES-256
		key := make([]byte, 32)
		copy(key, []byte(encryptionKey))

		// Create AES cipher block
		block, err := aes.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("failed to create cipher: %v", err)
		}

		// Create GCM mode
		gcm, err = cipher.NewGCM(block)
		if err != nil {
			return nil, fmt.Errorf("failed to create GCM: %v", err)
		}
	}

	database := &Database{DB: db, gcm: gcm}

	// Run migrations
	if err := database.runMigrations(); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %v", err)
	}

	return database, nil
}

// Close closes the database connection
func (d *Database) Close() error {
	return d.DB.Close()
}

// Encrypt encrypts data using AES-GCM
func (d *Database) Encrypt(plaintext []byte) ([]byte, error) {
	if d.gcm == nil {
		return plaintext, nil // No encryption configured
	}

	// Create a new nonce for each encryption
	nonce := make([]byte, d.gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	// Encrypt and append nonce
	ciphertext := d.gcm.Seal(nonce, nonce, plaintext, nil)
	return ciphertext, nil
}

// Decrypt decrypts data using AES-GCM
func (d *Database) Decrypt(ciphertext []byte) ([]byte, error) {
	if d.gcm == nil {
		return ciphertext, nil // No encryption configured
	}

	// Extract nonce from ciphertext
	nonceSize := d.gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]

	// Decrypt
	return d.gcm.Open(nil, nonce, ciphertext, nil)
}

// runMigrations runs database migrations
func (d *Database) runMigrations() error {
	log.Println("Running database migrations...")

	// Create threats table
	_, err := d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS threats (
			id SERIAL PRIMARY KEY,
			name TEXT NOT NULL,
			severity TEXT NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create threats table: %v", err)
	}

	// Create queries table
	_, err = d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS queries (
			id SERIAL PRIMARY KEY,
			query TEXT NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create queries table: %v", err)
	}

	// Create contact_messages table
	_, err = d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS contact_messages (
			id SERIAL PRIMARY KEY,
			name VARCHAR(255) NOT NULL,
			email VARCHAR(255) NOT NULL,
			company VARCHAR(200),
			message TEXT NOT NULL,
			status VARCHAR(50) NOT NULL DEFAULT 'unread',
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			responded_at TIMESTAMP WITH TIME ZONE
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create contact_messages table: %v", err)
	}

	// Create users table
	_, err = d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			email VARCHAR(255) NOT NULL UNIQUE,
			password_hash VARCHAR(255) NOT NULL,
			first_name VARCHAR(100) NOT NULL,
			last_name VARCHAR(100) NOT NULL,
			company VARCHAR(200),
			phone VARCHAR(50),
			role VARCHAR(50) NOT NULL DEFAULT 'user',
			active BOOLEAN NOT NULL DEFAULT TRUE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create users table: %v", err)
	}

	// Create tickets table
	_, err = d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS tickets (
			id SERIAL PRIMARY KEY,
			title VARCHAR(255) NOT NULL,
			description TEXT NOT NULL,
			user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
			agent_type VARCHAR(50) NOT NULL,
			status VARCHAR(50) NOT NULL DEFAULT 'open',
			priority VARCHAR(50) NOT NULL DEFAULT 'medium',
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create tickets table: %v", err)
	}

	// Create ticket_comments table
	_, err = d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS ticket_comments (
			id SERIAL PRIMARY KEY,
			ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
			user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
			content TEXT NOT NULL,
			is_internal BOOLEAN NOT NULL DEFAULT FALSE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create ticket_comments table: %v", err)
	}

	// Insert some initial data
	_, err = d.DB.Exec(`
		INSERT INTO threats (name, severity) VALUES 
		('Malware Detection', 'High'),
		('Phishing Attempt', 'Medium'),
		('Suspicious Login', 'Low')
		ON CONFLICT DO NOTHING
	`)
	if err != nil {
		log.Printf("Warning: failed to insert initial threat data: %v", err)
	}

	log.Println("Database migrations completed successfully")
	return nil
}

// Helper function to get environment variable with fallback
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
