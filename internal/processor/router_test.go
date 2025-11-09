package processor

import (
	"context"
	"testing"

	"github.com/rdavison/messaging-service/internal/domain"
	"github.com/rdavison/messaging-service/internal/provider"
)

type stubProv struct{ name string }

func (s stubProv) Send(_ context.Context, _ domain.Message) (provider.Response, error) {
	return provider.Response{
		ProviderID: s.name,
		Status:     domain.StatusOK,
	}, nil
}

func TestSimpleRouterChooseProvider(t *testing.T) {
	r := SimpleRouter{
		SMS:   stubProv{"twilio"},
		Email: stubProv{"sendgrid"},
	}

	// phone → phone message
	phoneMsg := domain.Message{
		Source: domain.Endpoint{
			Kind:    domain.EndpointKindPhone,
			Payload: "+12016661234",
		},
		Target: domain.Endpoint{
			Kind:    domain.EndpointKindPhone,
			Payload: "+18045551234",
		},
	}

	// email → email message
	emailMsg := domain.Message{
		Source: domain.Endpoint{
			Kind:    domain.EndpointKindEmail,
			Payload: "from@example.com",
		},
		Target: domain.Endpoint{
			Kind:    domain.EndpointKindEmail,
			Payload: "to@example.com",
		},
	}

	p1, err := r.ChooseProvider(phoneMsg)
	if err != nil {
		t.Fatalf("router error: %v", err)
	}
	resp1, err := p1.Send(context.Background(), domain.Message{})
	if err != nil {
		t.Fatalf("send error: %v", err)
	}
	if resp1.ProviderID != "twilio" {
		t.Fatalf("want providerID=twilio, got %s", resp1.ProviderID)
	}

	p2, err := r.ChooseProvider(emailMsg)
	if err != nil {
		t.Fatalf("router error: %v", err)
	}
	resp2, err := p2.Send(context.Background(), domain.Message{})
	if err != nil {
		t.Fatalf("send error: %v", err)
	}
	if resp2.ProviderID != "sendgrid" {
		t.Fatalf("want providerID=sendgrid, got %s", resp2.ProviderID)
	}
}
