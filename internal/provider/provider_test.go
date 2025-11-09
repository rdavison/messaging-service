package provider

import (
	"context"
	"math/rand"
	"testing"
	"time"

	"github.com/rdavison/messaging-service/internal/domain"
)

func TestProvidersRandomizeStatus(t *testing.T) {
	rand.Seed(time.Now().UnixNano())

	// Build endpoints with new domain model
	ch := domain.PhoneChannelSMS
	msg := domain.Message{
		ConversationID: 1,
		Source: domain.Endpoint{
			Kind:    domain.EndpointKindPhone,
			Channel: &ch,
			Payload: "+12016661234",
		},
		Target: domain.Endpoint{
			Kind:    domain.EndpointKindPhone,
			Channel: &ch,
			Payload: "+18045551234",
		},
		Direction:   domain.Outbound,
		SentAt:      time.Now(),
		Body:        "hi",
		Attachments: nil,
		Status:      domain.StatusOutbox,
	}

	providers := []Provider{
		TwilioProvider{},
		SendgridProvider{},
	}

	for _, p := range providers {
		seen := map[domain.Status]bool{}
		for i := 0; i < 12; i++ {
			resp, err := p.Send(context.Background(), msg)
			if err != nil {
				t.Fatalf("Send error: %v", err)
			}
			switch resp.Status {
			case domain.StatusOK, domain.StatusFailed, domain.StatusRetry:
				seen[resp.Status] = true
			default:
				t.Fatalf("unexpected status %q", resp.Status)
			}
		}
		if len(seen) == 0 {
			t.Fatal("no statuses observed")
		}
	}
}
