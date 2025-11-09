package api

import (
	"github.com/rdavison/messaging-service/internal/domain"
	"github.com/rdavison/messaging-service/internal/repo"
)

type handler struct {
	convs *repo.ConversationRepo
	msgs  *repo.MessageRepo
}

type conversationsResponse struct {
	Conversations []domain.Conversation `json:"conversations"`
}

type messagesResponse struct {
	Messages []domain.Message `json:"messages"`
}

type idResponse struct {
	ID string `json:"id"`
}

// Messages SMS Outbound: POST /messages/sms
type smsOutboundRequest struct {
	From        string   `json:"from"`
	To          string   `json:"to"`
	Type        string   `json:"type"` // "sms" | "mms"
	Body        string   `json:"body"`
	Attachments []string `json:"attachments,omitempty"`
	Timestamp   string   `json:"timestamp"` // RFC3339
}

// Messages Email Outbound: POST /messages/email
type emailOutboundRequest struct {
	From        string   `json:"from"`
	To          string   `json:"to"`
	Body        string   `json:"body"`
	Attachments []string `json:"attachments,omitempty"`
	Timestamp   string   `json:"timestamp"` // RFC3339
}

// Webhooks SMS Inbound: POST /webhooks/sms
type smsInboundRequest struct {
	From        string   `json:"from"`
	To          string   `json:"to"`
	Type        string   `json:"type"` // "sms" | "mms"
	Body        string   `json:"body"`
	Attachments []string `json:"attachments,omitempty"`
	Timestamp   string   `json:"timestamp"`
	// plus dynamic: "<provider>_id": "...", e.g., "twilio_id"
}

// Webhooks Email Inbound: POST /webhooks/email
type emailInboundRequest struct {
	From        string   `json:"from"`
	To          string   `json:"to"`
	Body        string   `json:"body"`
	Attachments []string `json:"attachments,omitempty"`
	Timestamp   string   `json:"timestamp"`
	// plus dynamic: "<provider>_id": "..."
}
