package api

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/rdavison/messaging-service/internal/domain"
	"github.com/rdavison/messaging-service/internal/repo"
)

var (
	ErrBadID        = errors.New("bad id")
	ErrBadType      = errors.New("bad type")
	ErrBadTimestamp = errors.New("bad timestamp")
	ErrNotFound     = errors.New("not found")
	ErrNoProvider   = errors.New("missing provider id key")
)

// getConversations returns all conversations or a single one (wrapped in a slice).
func (h *handler) getConversations(ctx context.Context, idStr *string) ([]domain.Conversation, error) {
	if idStr == nil {
		return h.convs.ListAll(ctx)
	}
	id, err := strconv.ParseInt(*idStr, 10, 64)
	if err != nil {
		return nil, ErrBadID
	}
	c, err := h.convs.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return []domain.Conversation{c}, nil
}

// getConversationMessages returns all valid messages for a given conversation id.
func (h *handler) getConversationMessages(ctx context.Context, convIDStr string, limit, offset int) ([]domain.Message, error) {
	id, err := strconv.ParseInt(convIDStr, 10, 64)
	if err != nil {
		return nil, ErrBadID
	}
	// rely on FK or explicit existence check
	ok, err := h.convs.Exists(ctx, id)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotFound
	}
	return h.msgs.GetByConversation(ctx, id, limit, offset)
}

// getMessages returns all messages or a single one (wrapped in a slice).
func (h *handler) getMessages(ctx context.Context, idStr *string, limit, offset int) ([]domain.Message, error) {
	if idStr == nil {
		return h.msgs.All(ctx, limit, offset)
	}
	id, err := strconv.ParseInt(*idStr, 10, 64)
	if err != nil {
		return nil, ErrBadID
	}
	m, err := h.msgs.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return []domain.Message{m}, nil
}

// createSMSOutbound receives an outbound sms message and saves it to the outbox
func (h *handler) createSMSOutbound(ctx context.Context, req smsOutboundRequest) (int64, error) {
	ts, err := time.Parse(time.RFC3339, req.Timestamp)
	if err != nil {
		return 0, ErrBadTimestamp
	}
	ch := domain.PhoneChannel(strings.ToLower(req.Type))
	if ch != domain.PhoneChannelSMS && ch != domain.PhoneChannelMMS {
		return 0, ErrBadType
	}
	source := domain.Endpoint{Kind: domain.EndpointKindPhone, Channel: &ch, Payload: req.From}
	target := domain.Endpoint{Kind: domain.EndpointKindPhone, Channel: &ch, Payload: req.To}
	convID, err := h.convs.GetOrCreateByEndpoints(ctx, source, target)
	if err != nil {
		return 0, err
	}
	msg := domain.Message{
		ConversationID: convID,
		Source:         source,
		Target:         target,
		Direction:      domain.Outbound,
		SentAt:         ts,
		Body:           req.Body,
		Attachments:    toAttachments(req.Attachments),
		Status:         domain.StatusOutbox,
	}
	return h.msgs.Insert(ctx, msg)
}

// createEmailOutbound receives an outbound email message and saves it to the outbox
func (h *handler) createEmailOutbound(ctx context.Context, req emailOutboundRequest) (int64, error) {
	ts, err := time.Parse(time.RFC3339, req.Timestamp)
	if err != nil {
		return 0, ErrBadTimestamp
	}
	source := domain.Endpoint{Kind: domain.EndpointKindEmail, Payload: req.From}
	target := domain.Endpoint{Kind: domain.EndpointKindEmail, Payload: req.To}
	convID, err := h.convs.GetOrCreateByEndpoints(ctx, source, target)
	if err != nil {
		return 0, err
	}
	msg := domain.Message{
		ConversationID: convID,
		Source:         source,
		Target:         target,
		Direction:      domain.Outbound,
		SentAt:         ts,
		Body:           req.Body,
		Attachments:    toAttachments(req.Attachments),
		Status:         domain.StatusOutbox,
	}
	return h.msgs.Insert(ctx, msg)
}

// createSMSInbound receives an inbound sms message from a provider and saves it
func (h *handler) createSMSInbound(ctx context.Context, raw map[string]any) (int64, error) {
	provider, providerMsgID, ok := extractProviderID(raw)
	if !ok {
		return 0, ErrNoProvider
	}
	b, _ := json.Marshal(raw)
	var req smsInboundRequest
	if err := json.Unmarshal(b, &req); err != nil {
		return 0, err
	}
	ts, err := time.Parse(time.RFC3339, req.Timestamp)
	if err != nil {
		return 0, ErrBadTimestamp
	}
	ch := domain.PhoneChannel(strings.ToLower(req.Type))
	if ch != domain.PhoneChannelSMS && ch != domain.PhoneChannelMMS {
		return 0, ErrBadType
	}
	source := domain.Endpoint{Kind: domain.EndpointKindPhone, Channel: &ch, Payload: req.From}
	target := domain.Endpoint{Kind: domain.EndpointKindPhone, Channel: &ch, Payload: req.To}
	convID, err := h.convs.GetOrCreateByEndpoints(ctx, source, target)
	if err != nil {
		return 0, err
	}
	msg := domain.Message{
		ConversationID: convID,
		Source:         source,
		Target:         target,
		Provider:       provRef(provider.String(), providerMsgID),
		Direction:      domain.Inbound,
		SentAt:         ts,
		Body:           req.Body,
		Attachments:    toAttachments(req.Attachments),
		Status:         domain.StatusOK,
	}
	return h.msgs.InsertOrUpdateByProviderPair(ctx, msg)
}

// createEmailInbound receives an inbound email message from a provider and saves it
func (h *handler) createEmailInbound(ctx context.Context, raw map[string]any) (int64, error) {
	provider, providerMsgID, ok := extractProviderID(raw)
	if !ok {
		return 0, ErrNoProvider
	}
	b, _ := json.Marshal(raw)
	var req emailInboundRequest
	if err := json.Unmarshal(b, &req); err != nil {
		return 0, err
	}
	ts, err := time.Parse(time.RFC3339, req.Timestamp)
	if err != nil {
		return 0, ErrBadTimestamp
	}
	source := domain.Endpoint{Kind: domain.EndpointKindEmail, Payload: req.From}
	target := domain.Endpoint{Kind: domain.EndpointKindEmail, Payload: req.To}
	convID, err := h.convs.GetOrCreateByEndpoints(ctx, source, target)
	if err != nil {
		return 0, err
	}
	msg := domain.Message{
		ConversationID: convID,
		Source:         source,
		Target:         target,
		Provider:       provRef(provider.String(), providerMsgID),
		Direction:      domain.Inbound,
		SentAt:         ts,
		Body:           req.Body,
		Attachments:    toAttachments(req.Attachments),
		Status:         domain.StatusOK,
	}
	return h.msgs.InsertOrUpdateByProviderPair(ctx, msg)
}

// toAttachments converts []string into []domain.Attachment (alias string).
func toAttachments(in []string) []domain.Attachment {
	if len(in) == 0 {
		return nil
	}
	out := make([]domain.Attachment, len(in))
	for i := range in {
		out[i] = domain.Attachment(in[i])
	}
	return out
}

// provRef builds a ProviderRef pointer only when at least one field is non-empty.
func provRef(id, messageID string) *domain.ProviderRef {
	if id == "" && messageID == "" {
		return nil
	}
	p := &domain.ProviderRef{ID: id, MessageID: messageID}
	return p
}
