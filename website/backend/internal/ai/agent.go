package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/ClarityXDR/prod/website/backend/internal/models"
	"log"
	"time"
)

// Agent represents an AI agent in the system
type Agent interface {
	ProcessTickets(ctx context.Context) error
	HandleTicket(ctx context.Context, ticket *models.Ticket) error
	GetAgentType() models.AgentType
}

// BaseAgent implements common functionality for all agents
type BaseAgent struct {
	TicketService models.TicketService
	AgentType     models.AgentType
	Name          string
	Description   string
}

// NewAgent creates a specific agent based on agent type
func NewAgent(agentType models.AgentType, ticketService models.TicketService) (Agent, error) {
	switch agentType {
	case models.AgentTypeCustomerService:
		return &CustomerServiceAgent{
			BaseAgent: BaseAgent{
				TicketService: ticketService,
				AgentType:     models.AgentTypeCustomerService,
				Name:          "Customer Service AI",
				Description:   "Handles customer inquiries and support requests",
			},
		}, nil
	case models.AgentTypeKQLHunting:
		return &KQLHuntingAgent{
			BaseAgent: BaseAgent{
				TicketService: ticketService,
				AgentType:     models.AgentTypeKQLHunting,
				Name:          "KQL Hunting AI",
				Description:   "Performs advanced threat hunting using KQL in Microsoft Defender",
			},
		}, nil
	case models.AgentTypeSales:
		return &SalesAgent{
			BaseAgent: BaseAgent{
				TicketService: ticketService,
				AgentType:     models.AgentTypeSales,
				Name:          "Sales AI",
				Description:   "Handles sales inquiries, quotes, and follows up with leads",
			},
		}, nil
	case models.AgentTypeAccounting:
		return &AccountingAgent{
			BaseAgent: BaseAgent{
				TicketService: ticketService,
				AgentType:     models.AgentTypeAccounting,
				Name:          "Accounting AI",
				Description:   "Manages financial records and reporting",
			},
		}, nil
	case models.AgentTypeInvoicing:
		return &InvoicingAgent{
			BaseAgent: BaseAgent{
				TicketService: ticketService,
				AgentType:     models.AgentTypeInvoicing,
				Name:          "Invoicing AI",
				Description:   "Handles invoice generation and payment tracking",
			},
		}, nil
	default:
		return nil, fmt.Errorf("unknown agent type: %s", agentType)
	}
}

// GetAgentType returns the agent type
func (b *BaseAgent) GetAgentType() models.AgentType {
	return b.AgentType
}

// ProcessTickets fetches and processes tickets assigned to this agent type
func (b *BaseAgent) ProcessTickets(ctx context.Context) error {
	// Get all open tickets for this agent type
	tickets, err := b.TicketService.GetTicketsByAgent(b.AgentType)
	if err != nil {
		return err
	}

	// Process each ticket
	for _, ticket := range tickets {
		// Skip tickets that are not open or in progress
		if ticket.Status != models.TicketStatusOpen && ticket.Status != models.TicketStatusInProgress {
			continue
		}

		// Process the ticket in a goroutine
		go func(t *models.Ticket) {
			// Create a context with timeout for ticket processing
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
			defer cancel()

			if err := b.HandleTicket(ctx, t); err != nil {
				log.Printf("Error handling ticket %d: %v", t.ID, err)

				// Add comment about the error
				comment := &models.TicketComment{
					TicketID:   t.ID,
					Content:    fmt.Sprintf("Error processing ticket: %v", err),
					IsInternal: true,
				}
				b.TicketService.AddComment(comment)
			}
		}(ticket)
	}

	return nil
}

// HandleTicket is a placeholder to be implemented by specific agents
func (b *BaseAgent) HandleTicket(ctx context.Context, ticket *models.Ticket) error {
	return fmt.Errorf("HandleTicket not implemented for base agent")
}

// LogAction logs agent actions
func (b *BaseAgent) LogAction(ticketID int64, action string, data interface{}) {
	// Convert data to JSON for logging
	jsonData, err := json.Marshal(data)
	if err != nil {
		log.Printf("Error marshaling log data: %v", err)
		return
	}

	log.Printf("[%s] Ticket #%d: %s - %s", b.Name, ticketID, action, string(jsonData))
}

// CustomerServiceAgent handles customer inquiries
type CustomerServiceAgent struct {
	BaseAgent
}

// HandleTicket implements customer service ticket handling
func (a *CustomerServiceAgent) HandleTicket(ctx context.Context, ticket *models.Ticket) error {
	// Log the action
	a.LogAction(ticket.ID, "Processing customer service ticket", map[string]interface{}{
		"title":    ticket.Title,
		"priority": ticket.Priority,
	})

	// Update ticket status to in progress
	if ticket.Status == models.TicketStatusOpen {
		ticket.Status = models.TicketStatusInProgress
		ticket.UpdatedAt = time.Now()
		if err := a.TicketService.Update(ticket); err != nil {
			return err
		}

		// Add a comment that the AI is working on it
		comment := &models.TicketComment{
			TicketID:   ticket.ID,
			Content:    "I'm analyzing your request and will respond shortly.",
			IsInternal: false,
		}
		if err := a.TicketService.AddComment(comment); err != nil {
			return err
		}
	}

	// TODO: Add AI logic for natural language understanding and response generation
	// This would integrate with an NLP service like Azure OpenAI, OpenAI API, etc.

	// Simulate AI processing time
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(2 * time.Second):
		// Simulation complete
	}

	// Add AI response comment
	response := "Thank you for reaching out! Based on your inquiry, I recommend checking our documentation at https://docs.clarityxdr.com. If you need further assistance, please provide more details about your specific use case."
	comment := &models.TicketComment{
		TicketID:   ticket.ID,
		Content:    response,
		IsInternal: false,
	}
	if err := a.TicketService.AddComment(comment); err != nil {
		return err
	}

	// Update ticket status to resolved
	ticket.Status = models.TicketStatusResolved
	ticket.ResolvedAt = time.Now()
	ticket.UpdatedAt = time.Now()

	return a.TicketService.Update(ticket)
}

// KQLHuntingAgent handles security threat hunting
type KQLHuntingAgent struct {
	BaseAgent
}

// HandleTicket implements KQL hunting ticket processing
func (a *KQLHuntingAgent) HandleTicket(ctx context.Context, ticket *models.Ticket) error {
	// Implementation for KQL hunting
	// ...
	return nil
}

// SalesAgent handles sales inquiries and quotes
type SalesAgent struct {
	BaseAgent
}

// HandleTicket implements sales ticket processing
func (a *SalesAgent) HandleTicket(ctx context.Context, ticket *models.Ticket) error {
	// Implementation for sales ticket handling
	// ...
	return nil
}

// AccountingAgent handles accounting operations
type AccountingAgent struct {
	BaseAgent
}

// HandleTicket implements accounting ticket processing
func (a *AccountingAgent) HandleTicket(ctx context.Context, ticket *models.Ticket) error {
	// Implementation for accounting operations
	// ...
	return nil
}

// InvoicingAgent handles invoicing and payment tracking
type InvoicingAgent struct {
	BaseAgent
}

// HandleTicket implements invoicing ticket processing
func (a *InvoicingAgent) HandleTicket(ctx context.Context, ticket *models.Ticket) error {
	// Implementation for invoicing operations
	// ...
	return nil
}
}
