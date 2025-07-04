package db

import (
	"database/sql"
	"log"
)

// RunMigrations runs all database migrations
func RunMigrations(db *sql.DB) error {
	log.Println("Running database migrations...")

	// Create tables
	migrations := []string{
		createUsersTableSQL,
		createTokensTableSQL,
		createTicketsTableSQL,
		createTicketCommentsTableSQL,
		createTicketAttachmentsTableSQL,
		createClientsTableSQL,
		createInvoicesTableSQL,
		createInvoiceItemsTableSQL,
		createProductsTableSQL,
		createQuotesTableSQL,
		createQuoteItemsTableSQL,
		createSalesLeadsTableSQL,
		createContactMessagesTableSQL,
		createConfigTableSQL,
		createAuditLogTableSQL,
		createGitRepositoriesTableSQL,
	}

	for _, migration := range migrations {
		_, err := db.Exec(migration)
		if err != nil {
			log.Printf("Migration failed: %v", err)
			return err
		}
	}

	log.Println("Database migrations completed successfully")
	return nil
}

const createUsersTableSQL = `
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
	verified_at TIMESTAMP WITH TIME ZONE,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	last_login_at TIMESTAMP WITH TIME ZONE,
	two_factor_secret VARCHAR(255),
	two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
	api_token VARCHAR(255)
);
`

const createTokensTableSQL = `
CREATE TABLE IF NOT EXISTS tokens (
	id SERIAL PRIMARY KEY,
	user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	token VARCHAR(255) NOT NULL UNIQUE,
	type VARCHAR(50) NOT NULL,
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
`

const createTicketsTableSQL = `
CREATE TABLE IF NOT EXISTS tickets (
	id SERIAL PRIMARY KEY,
	title VARCHAR(255) NOT NULL,
	description TEXT NOT NULL,
	user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
	agent_type VARCHAR(50) NOT NULL,
	status VARCHAR(50) NOT NULL,
	priority VARCHAR(50) NOT NULL,
	assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	resolved_at TIMESTAMP WITH TIME ZONE,
	due_at TIMESTAMP WITH TIME ZONE,
	tags TEXT[]
);
`

const createTicketCommentsTableSQL = `
CREATE TABLE IF NOT EXISTS ticket_comments (
	id SERIAL PRIMARY KEY,
	ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
	user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
	content TEXT NOT NULL,
	is_internal BOOLEAN NOT NULL DEFAULT FALSE,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
`

const createTicketAttachmentsTableSQL = `
CREATE TABLE IF NOT EXISTS ticket_attachments (
	id SERIAL PRIMARY KEY,
	ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
	file_name VARCHAR(255) NOT NULL,
	file_size BIGINT NOT NULL,
	content_type VARCHAR(100) NOT NULL,
	storage_path VARCHAR(500) NOT NULL,
	uploaded_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
`

const createClientsTableSQL = `
CREATE TABLE IF NOT EXISTS clients (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	email VARCHAR(255) NOT NULL,
	phone VARCHAR(50),
	address TEXT,
	contact_person VARCHAR(200),
	status VARCHAR(50) NOT NULL DEFAULT 'active',
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
`

const createInvoicesTableSQL = `
CREATE TABLE IF NOT EXISTS invoices (
	id SERIAL PRIMARY KEY,
	client_id INTEGER NOT NULL REFERENCES clients(id),
	invoice_number VARCHAR(50) NOT NULL UNIQUE,
	issue_date DATE NOT NULL,
	due_date DATE NOT NULL,
	status VARCHAR(50) NOT NULL DEFAULT 'draft',
	subtotal DECIMAL(10, 2) NOT NULL,
	tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
	total_amount DECIMAL(10, 2) NOT NULL,
	notes TEXT,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	paid_at TIMESTAMP WITH TIME ZONE
);
`

const createInvoiceItemsTableSQL = `
CREATE TABLE IF NOT EXISTS invoice_items (
	id SERIAL PRIMARY KEY,
	invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
	product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
	description TEXT NOT NULL,
	quantity DECIMAL(10, 2) NOT NULL,
	unit_price DECIMAL(10, 2) NOT NULL,
	total_price DECIMAL(10, 2) NOT NULL
);
`

const createProductsTableSQL = `
CREATE TABLE IF NOT EXISTS products (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	description TEXT,
	sku VARCHAR(50),
	price DECIMAL(10, 2) NOT NULL,
	tax_rate DECIMAL(5, 2) DEFAULT 0,
	active BOOLEAN NOT NULL DEFAULT TRUE,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
`

const createQuotesTableSQL = `
CREATE TABLE IF NOT EXISTS quotes (
	id SERIAL PRIMARY KEY,
	client_id INTEGER NOT NULL REFERENCES clients(id),
	quote_number VARCHAR(50) NOT NULL UNIQUE,
	issue_date DATE NOT NULL,
	expiry_date DATE NOT NULL,
	status VARCHAR(50) NOT NULL DEFAULT 'draft',
	subtotal DECIMAL(10, 2) NOT NULL,
	tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
	total_amount DECIMAL(10, 2) NOT NULL,
	notes TEXT,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	converted_to_invoice_id INTEGER REFERENCES invoices(id)
);
`

const createQuoteItemsTableSQL = `
CREATE TABLE IF NOT EXISTS quote_items (
	id SERIAL PRIMARY KEY,
	quote_id INTEGER NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
	product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
	description TEXT NOT NULL,
	quantity DECIMAL(10, 2) NOT NULL,
	unit_price DECIMAL(10, 2) NOT NULL,
	total_price DECIMAL(10, 2) NOT NULL
);
`

const createSalesLeadsTableSQL = `
CREATE TABLE IF NOT EXISTS sales_leads (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	email VARCHAR(255) NOT NULL,
	company VARCHAR(200),
	phone VARCHAR(50),
	source VARCHAR(100),
	status VARCHAR(50) NOT NULL DEFAULT 'new',
	assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
	notes TEXT,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	last_contact_at TIMESTAMP WITH TIME ZONE
);
`

const createContactMessagesTableSQL = `
CREATE TABLE IF NOT EXISTS contact_messages (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	email VARCHAR(255) NOT NULL,
	company VARCHAR(200),
	message TEXT NOT NULL,
	status VARCHAR(50) NOT NULL DEFAULT 'unread',
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	responded_at TIMESTAMP WITH TIME ZONE,
	responded_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);
`

const createConfigTableSQL = `
CREATE TABLE IF NOT EXISTS config (
	key VARCHAR(255) PRIMARY KEY,
	value TEXT NOT NULL,
	description TEXT,
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);
`

const createAuditLogTableSQL = `
CREATE TABLE IF NOT EXISTS audit_log (
	id SERIAL PRIMARY KEY,
	user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
	action VARCHAR(100) NOT NULL,
	entity_type VARCHAR(100) NOT NULL,
	entity_id INTEGER,
	description TEXT,
	ip_address VARCHAR(45),
	user_agent TEXT,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
`

const createGitRepositoriesTableSQL = `
CREATE TABLE IF NOT EXISTS git_repositories (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	description TEXT,
	path VARCHAR(500) NOT NULL,
	is_private BOOLEAN NOT NULL DEFAULT TRUE,
	owner_id INTEGER NOT NULL REFERENCES users(id),
	created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	last_commit_hash VARCHAR(100),
	last_commit_message TEXT,
	last_commit_at TIMESTAMP WITH TIME ZONE
);
`
