package provider

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"github.com/google/uuid"
	"github.com/rdavison/messaging-service/internal/domain"
)

type SendgridProvider struct{}

func (s SendgridProvider) Send(ctx context.Context, m domain.Message) (Response, error) {
	// Simulate latency
	time.Sleep(time.Duration(100+rand.Intn(200)) * time.Millisecond)

	// Randomize outcome
	outcomes := []domain.Status{
		domain.StatusOK,
		domain.StatusFailed,
		domain.StatusRetry,
	}
	status := outcomes[rand.Intn(len(outcomes))]
	// TODO: call SendGrid API; on success:
	pmID := fmt.Sprintf("sendgrid-%s", uuid.NewString())
	payload := "Twilio simulated status: " + string(status)
	return Response{
		ProviderID:        "sendgrid",
		ProviderMessageID: pmID,
		Status:            status,
		StatusPayload:     &payload,
	}, nil
}
