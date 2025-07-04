package models

import (
	"time"
)

// TicketStatus defines the status of a ticket
type TicketStatus string

// TicketPriority defines the priority level of a ticket
type TicketPriority string

// AgentType defines the type of AI agent assigned to a ticket
type AgentType string

const (
	// Ticket statuses
	TicketStatusOpen       TicketStatus = "open"
	TicketStatusInProgress TicketStatus = "in_progress"
	TicketStatusWaiting    TicketStatus = "waiting"
	TicketStatusResolved   TicketStatus = "resolved"
	TicketStatusClosed     TicketStatus = "closed"

	// Ticket priorities
	TicketPriorityLow      TicketPriority = "low"
	TicketPriorityMedium   TicketPriority = "medium"
	TicketPriorityHigh     TicketPriority = "high"
	TicketPriorityCritical TicketPriority = "critical"

	// Agent types
	AgentTypeCustomerService AgentType = "customer_service"
	AgentTypeKQLHunting      AgentType = "kql_hunting"
	AgentTypeSales           AgentType = "sales"
	AgentTypeAccounting      AgentType = "accounting"
	AgentTypeInvoicing       AgentType = "invoicing"
)

// Ticket represents a support or task ticket in the system
type Ticket struct {
	ID          int64          `json:"id"`
	Title       string         `json:"title"`
	Description string         `json:"description"`
	UserID      int64          `json:"user_id"`
	AgentType   AgentType      `json:"agent_type"`
	Status      TicketStatus   `json:"status"`
	Priority    TicketPriority `json:"priority"`
	AssignedTo  int64          `json:"assigned_to,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	ResolvedAt  time.Time      `json:"resolved_at,omitempty"`
	DueAt       time.Time      `json:"due_at,omitempty"`
	Tags        []string       `json:"tags,omitempty"`
}

// TicketComment represents a comment on a ticket
type TicketComment struct {
	ID         int64     `json:"id"`
	TicketID   int64     `json:"ticket_id"`
	UserID     int64     `json:"user_id"`
	Content    string    `json:"content"`
	IsInternal bool      `json:"is_internal"`
	CreatedAt  time.Time `json:"created_at"`
}

// TicketAttachment represents a file attached to a ticket
type TicketAttachment struct {
	ID          int64     `json:"id"`
	TicketID    int64     `json:"ticket_id"`
	FileName    string    `json:"file_name"`
	FileSize    int64     `json:"file_size"`
	ContentType string    `json:"content_type"`
	StoragePath string    `json:"-"`
	UploadedBy  int64     `json:"uploaded_by"`
	CreatedAt   time.Time `json:"created_at"`
}

// TicketService defines methods for ticket management
type TicketService interface {
	Create(ticket *Ticket) error
	GetByID(id int64) (*Ticket, error)
	Update(ticket *Ticket) error
	Delete(id int64) error
	GetTicketsByUser(userID int64) ([]*Ticket, error)
	GetTicketsByStatus(status TicketStatus) ([]*Ticket, error)
	GetTicketsByAgent(agentType AgentType) ([]*Ticket, error)
	AssignToAgent(ticketID, userID int64) error

	// Comment methods
	AddComment(comment *TicketComment) error
	GetCommentsByTicket(ticketID int64) ([]*TicketComment, error)

	// Attachment methods
	AddAttachment(attachment *TicketAttachment, data []byte) error
	GetAttachmentsByTicket(ticketID int64) ([]*TicketAttachment, error)
	GetAttachmentData(attachmentID int64) ([]byte, *TicketAttachment, error)
}
