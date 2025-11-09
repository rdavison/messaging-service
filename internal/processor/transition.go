package processor

import (
	"context"
	"fmt"

	"github.com/rdavison/messaging-service/internal/domain"
)

func (e *Entrypoint) TransitionStatus(ctx context.Context, id int64) (domain.Status, error) {
	// load message
	m, err := e.msgs.GetByID(ctx, id)
	if err != nil {
		return "", fmt.Errorf("get message: %w", err)
	}

	// early abort if there's nothing to do
	if domain.IsStatusTerminal(m.Status) {
		return m.Status, nil
	}

	// choose a provider to handle the current message type
	prov, err := e.router.ChooseProvider(m)
	if err != nil {
		// route failure -> retry with payload
		payload := "route error: " + err.Error()
		_ = e.msgs.UpdateStatus(ctx, id, domain.StatusRetry, nil, nil, &payload)
		return domain.StatusRetry, err
	}

	// send via provider; providers encapsulate the "send_and_transition_status" logic
	resp, sendErr := prov.Send(ctx, m)
	if sendErr != nil {
		payload := "send error: " + sendErr.Error()
		_ = e.msgs.UpdateStatus(ctx, id, domain.StatusRetry, nil, nil, &payload)
		return domain.StatusRetry, sendErr
	}

	// For the processor, mutate the CURRENT row by id.
	// Use the conflict-safe guarded UPDATE so we never violate the unique (provider_id, provider_message_id).
	if resp.ProviderID != "" && resp.ProviderMessageID != "" {
		fmt.Printf("status = %s ; provider = %s ; message_id = %s ; ", resp.Status, resp.ProviderID, resp.ProviderMessageID)
		if err := e.msgs.UpdateStatus(ctx, id, resp.Status, &resp.ProviderID, &resp.ProviderMessageID, resp.StatusPayload); err != nil {
			return "", fmt.Errorf("update status with provider: %w", err)
		}
	} else {
		if err := e.msgs.UpdateStatus(ctx, id, resp.Status, nil, nil, resp.StatusPayload); err != nil {
			return "", fmt.Errorf("update status: %w", err)
		}
	}
	return resp.Status, nil
}
