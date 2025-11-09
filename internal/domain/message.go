package domain

import (
	"time"
)

type ProviderRef struct {
	ID        string `json:"id"`         // e.g., "twilio", "sendgrid"
	MessageID string `json:"message_id"` // provider-assigned message id
}

// Message is the domain entity used throughout business logic and APIs.
type Message struct {
	ID             int64             `json:"id"`
	ConversationID int64             `json:"conversation_id"`
	Source         Endpoint          `json:"source"`
	Target         Endpoint          `json:"target"`
	Direction      InboundOrOutbound `json:"direction"`
	SentAt         time.Time         `json:"sent_at"`
	Body           string            `json:"body"`
	Attachments    []Attachment      `json:"attachments,omitempty"`
	Status         Status            `json:"status"`
	StatusPayload  *string           `json:"status_payload,omitempty"`
	Provider       *ProviderRef      `json:"provider,omitempty"`
	CreatedAt      time.Time         `json:"created_at"`
	UpdatedAt      time.Time         `json:"updated_at"`
}
