package provider

import (
	"context"

	"github.com/rdavison/messaging-service/internal/domain"
)

// Response is the outcome of a provider Send attempt.
type Response struct {
	ProviderID        string
	ProviderMessageID string
	Status            domain.Status
	StatusPayload     *string
}

// Provider is implemented by concrete providers (Twilio, Sendgrid, etc.).
type Provider interface {
	Send(ctx context.Context, m domain.Message) (Response, error)
}
