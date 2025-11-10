package repo

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/rdavison/messaging-service/internal/domain"
)

type MessageRepo struct {
	Pool *pgxpool.Pool
}

func NewMessageRepo(pool *pgxpool.Pool) *MessageRepo {
	return &MessageRepo{Pool: pool}
}

// Insert inserts a message row and returns the new id.
func (r *MessageRepo) Insert(ctx context.Context, m domain.Message) (int64, error) {
	const q = `
INSERT INTO messages (
  conversation_id,
  endpoint_source,
  endpoint_target,
  provider_id,
  provider_message_id,
  inbound_or_outbound,
  sent_at,
  endpoint_kind,
  phone_channel,
  body,
  attachments,
  status_tag,
  status_payload
) VALUES (
  $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
) ON CONFLICT (provider_id, provider_message_id) DO
  UPDATE SET updated_at = EXCLUDED.updated_at
  RETURNING id
`
	var phoneCh *string
	if m.Source.Channel != nil {
		v := m.Source.Channel.String()
		phoneCh = &v
	}

	var provID, provMsgID *string
	if m.Provider != nil {
		if m.Provider.ID != "" {
			provID = &m.Provider.ID
		}
		if m.Provider.MessageID != "" {
			provMsgID = &m.Provider.MessageID
		}
	}

	attJSON := encodeAttachments(m.Attachments)

	var id int64
	err := r.Pool.QueryRow(ctx, q,
		m.ConversationID,
		m.Source.Payload,
		m.Target.Payload,
		provID,
		provMsgID,
		string(m.Direction),
		m.SentAt,
		string(m.Source.Kind),
		phoneCh,
		m.Body,
		nullableJSON(attJSON),
		string(m.Status),
		m.StatusPayload,
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("insert message: %w", err)
	}
	return id, nil
}

// Updates the status of a message with a given id. Optionally updates providerID and
// providerMessageID if they are passed in as well.
func (r *MessageRepo) UpdateStatus(
	ctx context.Context,
	id int64,
	newStatus domain.Status,
	providerID *string,
	providerMessageID *string,
	statusPayload *string,
) error {
	if providerID == nil || providerMessageID == nil {
		const q = `
UPDATE messages
SET status_tag = $1,
    status_payload = $2
WHERE id = $3;
`
		_, err := r.Pool.Exec(ctx, q, string(newStatus), statusPayload, id)
		if err != nil {
			return fmt.Errorf("update message status: %w", err)
		}
		return nil
	}

	// Single statement that avoids unique violations by conditionally keeping
	// provider fields unchanged
	const q = `
UPDATE messages
SET
  status_tag     = $1,
  status_payload = $2,
  provider_id = CASE
    WHEN EXISTS (
      SELECT 1 FROM messages m2
      WHERE m2.provider_id IS NOT DISTINCT FROM $3
        AND m2.provider_message_id IS NOT DISTINCT FROM $4
        AND m2.id <> messages.id
    ) THEN provider_id
    ELSE $3
  END,
  provider_message_id = CASE
    WHEN EXISTS (
      SELECT 1 FROM messages m2
      WHERE m2.provider_id IS NOT DISTINCT FROM $3
        AND m2.provider_message_id IS NOT DISTINCT FROM $4
        AND m2.id <> messages.id
    ) THEN provider_message_id
    ELSE $4
  END
WHERE id = $5;
`
	_, err := r.Pool.Exec(ctx, q, string(newStatus), statusPayload, providerID, providerMessageID, id)
	if err != nil {
		return fmt.Errorf("update message status (CASE-guard): %w", err)
	}
	return nil
}

// PollOutboxOrRetry returns messages with status outbox/retry, oldest first.
func (r *MessageRepo) PollOutboxOrRetry(ctx context.Context, limit int) ([]domain.Message, error) {
	const q = `
SELECT
  id, conversation_id, endpoint_source, endpoint_target,
  provider_id, provider_message_id,
  inbound_or_outbound, sent_at, endpoint_kind, phone_channel,
  body, attachments, status_tag, status_payload,
  created_at, updated_at
FROM messages
WHERE status_tag IN ('outbox','retry')
ORDER BY sent_at ASC
LIMIT $1
`
	rows, err := r.Pool.Query(ctx, q, limit)
	if err != nil {
		return nil, fmt.Errorf("poll messages: %w", err)
	}
	defer rows.Close()

	var out []domain.Message
	for rows.Next() {
		var (
			id, convID                int64
			source, target            string
			providerID, providerMsgID *string
			dirStr, kindStr           string
			phoneCh                   *string
			body                      string
			attJSON                   *string
			statusStr                 string
			statusPayload             *string
			createdAt, updatedAt      time.Time
			sentAt                    time.Time
		)
		if err := rows.Scan(
			&id, &convID, &source, &target,
			&providerID, &providerMsgID,
			&dirStr, &sentAt, &kindStr, &phoneCh,
			&body, &attJSON, &statusStr, &statusPayload,
			&createdAt, &updatedAt,
		); err != nil {
			return nil, err
		}

		var ch *domain.PhoneChannel
		if phoneCh != nil {
			c := domain.PhoneChannel(*phoneCh)
			ch = &c
		}
		src := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: source, Channel: ch}
		trg := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: target, Channel: ch}

		var prov *domain.ProviderRef
		if providerID != nil || providerMsgID != nil {
			p := domain.ProviderRef{}
			if providerID != nil {
				p.ID = *providerID
			}
			if providerMsgID != nil {
				p.MessageID = *providerMsgID
			}
			prov = &p
		}

		if err := rows.Err(); err != nil {
			return nil, err
		}

		m := domain.Message{
			ID:             id,
			ConversationID: convID,
			Source:         src,
			Target:         trg,
			Direction:      domain.InboundOrOutbound(dirStr),
			SentAt:         sentAt,
			Body:           body,
			Attachments:    decodeAttachments(attJSON),
			Status:         domain.Status(statusStr),
			StatusPayload:  statusPayload,
			Provider:       prov,
			CreatedAt:      createdAt,
			UpdatedAt:      updatedAt,
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *MessageRepo) GetByConversation(ctx context.Context, convID int64, limit, offset int) ([]domain.Message, error) {
	const q = `
SELECT
  id, conversation_id, endpoint_source, endpoint_target,
  provider_id, provider_message_id,
  inbound_or_outbound, sent_at, endpoint_kind, phone_channel,
  body, attachments, status_tag, status_payload,
  created_at, updated_at
FROM messages
WHERE conversation_id = $1
ORDER BY sent_at ASC, id ASC
LIMIT $2 OFFSET $3
`
	rows, err := r.Pool.Query(ctx, q, convID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("get messages by conversation: %w", err)
	}
	defer rows.Close()

	var out []domain.Message
	for rows.Next() {
		var (
			id, convIDRow             int64
			source, target            string
			providerID, providerMsgID *string
			dirStr, kindStr           string
			phoneCh                   *string
			body                      string
			attJSON                   *string
			statusStr                 string
			statusPayload             *string
			sentAt                    time.Time
			createdAt, updatedAt      time.Time
		)
		if err := rows.Scan(
			&id, &convIDRow, &source, &target,
			&providerID, &providerMsgID,
			&dirStr, &sentAt, &kindStr, &phoneCh,
			&body, &attJSON, &statusStr, &statusPayload,
			&createdAt, &updatedAt,
		); err != nil {
			return nil, err
		}

		var ch *domain.PhoneChannel
		if phoneCh != nil {
			c := domain.PhoneChannel(*phoneCh)
			ch = &c
		}
		src := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: source, Channel: ch}
		trg := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: target, Channel: ch}

		var prov *domain.ProviderRef
		if providerID != nil || providerMsgID != nil {
			p := domain.ProviderRef{}
			if providerID != nil {
				p.ID = *providerID
			}
			if providerMsgID != nil {
				p.MessageID = *providerMsgID
			}
			prov = &p
		}

		m := domain.Message{
			ID:             id,
			ConversationID: convIDRow,
			Source:         src,
			Target:         trg,
			Direction:      domain.InboundOrOutbound(dirStr),
			SentAt:         sentAt,
			Body:           body,
			Attachments:    decodeAttachments(attJSON),
			Status:         domain.Status(statusStr),
			StatusPayload:  statusPayload,
			Provider:       prov,
			CreatedAt:      createdAt,
			UpdatedAt:      updatedAt,
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func nullableJSON(b []byte) any {
	if b == nil || len(b) == 0 {
		return nil
	}
	// We can send as text/json to pg. pgx will cast to jsonb in INSERT.
	return string(b)
}

func (r *MessageRepo) InsertOrUpdateByProviderPair(ctx context.Context, m domain.Message) (int64, error) {
	const q = `
INSERT INTO messages (
  conversation_id,
  endpoint_source,
  endpoint_target,
  provider_id,
  provider_message_id,
  inbound_or_outbound,
  sent_at,
  endpoint_kind,
  phone_channel,
  body,
  attachments,
  status_tag,
  status_payload
)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
ON CONFLICT (provider_id, provider_message_id)
DO UPDATE SET
  status_tag     = EXCLUDED.status_tag,
  status_payload = EXCLUDED.status_payload,
  updated_at     = now()
RETURNING id;
`
	var phoneCh *string
	if m.Source.Channel != nil {
		v := m.Source.Channel.String()
		phoneCh = &v
	}
	var provID, provMsgID *string
	if m.Provider != nil {
		if m.Provider.ID != "" {
			provID = &m.Provider.ID
		}
		if m.Provider.MessageID != "" {
			provMsgID = &m.Provider.MessageID
		}
	}
	attJSON := encodeAttachments(m.Attachments)

	var id int64
	if err := r.Pool.QueryRow(ctx, q,
		m.ConversationID,
		m.Source.Payload,
		m.Target.Payload,
		provID,
		provMsgID,
		string(m.Direction),
		m.SentAt,
		string(m.Source.Kind),
		phoneCh,
		m.Body,
		nullableJSON(attJSON),
		string(m.Status),
		m.StatusPayload,
	).Scan(&id); err != nil {
		return 0, fmt.Errorf("upsert messages by provider pair: %w", err)
	}
	return id, nil
}

var ErrNotFound = errors.New("not found")

func (r *MessageRepo) GetByID(ctx context.Context, id int64) (domain.Message, error) {
	const q = `
SELECT
  id, conversation_id, endpoint_source, endpoint_target,
  provider_id, provider_message_id,
  inbound_or_outbound, sent_at, endpoint_kind, phone_channel,
  body, attachments, status_tag, status_payload,
  created_at, updated_at
FROM messages
WHERE id = $1
`
	var (
		convID                    int64
		source, target            string
		providerID, providerMsgID *string
		dirStr, kindStr           string
		phoneCh                   *string
		body                      string
		attJSON                   *string
		statusStr                 string
		statusPayload             *string
		sentAt                    time.Time
		createdAt, updatedAt      time.Time
	)
	err := r.Pool.QueryRow(ctx, q, id).Scan(
		&id, &convID, &source, &target,
		&providerID, &providerMsgID,
		&dirStr, &sentAt, &kindStr, &phoneCh,
		&body, &attJSON, &statusStr, &statusPayload,
		&createdAt, &updatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.Message{}, ErrNotFound
		}
		return domain.Message{}, fmt.Errorf("get message by id: %w", err)
	}

	var ch *domain.PhoneChannel
	if phoneCh != nil {
		c := domain.PhoneChannel(*phoneCh)
		ch = &c
	}
	src := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: source, Channel: ch}
	trg := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: target, Channel: ch}

	var prov *domain.ProviderRef
	if providerID != nil || providerMsgID != nil {
		p := domain.ProviderRef{}
		if providerID != nil {
			p.ID = *providerID
		}
		if providerMsgID != nil {
			p.MessageID = *providerMsgID
		}
		prov = &p
	}

	m := domain.Message{
		ID:             id,
		ConversationID: convID,
		Source:         src,
		Target:         trg,
		Direction:      domain.InboundOrOutbound(dirStr),
		SentAt:         sentAt,
		Body:           body,
		Attachments:    decodeAttachments(attJSON),
		Status:         domain.Status(statusStr),
		StatusPayload:  statusPayload,
		Provider:       prov,
		CreatedAt:      createdAt,
		UpdatedAt:      updatedAt,
	}
	return m, nil
}

func (r *MessageRepo) All(ctx context.Context, limit, offset int) ([]domain.Message, error) {
	const q = `
SELECT
  id, conversation_id, endpoint_source, endpoint_target,
  provider_id, provider_message_id,
  inbound_or_outbound, sent_at, endpoint_kind, phone_channel,
  body, attachments, status_tag, status_payload,
  created_at, updated_at
FROM messages
ORDER BY sent_at DESC, id DESC
LIMIT $1 OFFSET $2
`
	rows, err := r.Pool.Query(ctx, q, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list messages: %w", err)
	}
	defer rows.Close()

	out := make([]domain.Message, 0)
	for rows.Next() {
		var (
			id, convID                int64
			source, target            string
			providerID, providerMsgID *string
			dirStr, kindStr           string
			phoneCh                   *string
			body                      string
			attJSON                   *string
			statusStr                 string
			statusPayload             *string
			sentAt                    time.Time
			createdAt, updatedAt      time.Time
		)
		if err := rows.Scan(
			&id, &convID, &source, &target,
			&providerID, &providerMsgID,
			&dirStr, &sentAt, &kindStr, &phoneCh,
			&body, &attJSON, &statusStr, &statusPayload,
			&createdAt, &updatedAt,
		); err != nil {
			return nil, err
		}

		var ch *domain.PhoneChannel
		if phoneCh != nil {
			c := domain.PhoneChannel(*phoneCh)
			ch = &c
		}
		src := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: source, Channel: ch}
		trg := domain.Endpoint{Kind: domain.EndpointKind(kindStr), Payload: target, Channel: ch}

		var prov *domain.ProviderRef
		if providerID != nil || providerMsgID != nil {
			p := domain.ProviderRef{}
			if providerID != nil {
				p.ID = *providerID
			}
			if providerMsgID != nil {
				p.MessageID = *providerMsgID
			}
			prov = &p
		}

		m := domain.Message{
			ID:             id,
			ConversationID: convID,
			Source:         src,
			Target:         trg,
			Direction:      domain.InboundOrOutbound(dirStr),
			SentAt:         sentAt,
			Body:           body,
			Attachments:    decodeAttachments(attJSON),
			Status:         domain.Status(statusStr),
			StatusPayload:  statusPayload,
			Provider:       prov,
			CreatedAt:      createdAt,
			UpdatedAt:      updatedAt,
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// encodeAttachments converts []domain.Attachment (alias string) into JSON bytes.
func encodeAttachments(atts []domain.Attachment) []byte {
	if len(atts) == 0 {
		return nil
	}
	arr := make([]string, len(atts))
	for i := range atts {
		arr[i] = string(atts[i])
	}
	b, _ := json.Marshal(arr)
	return b
}

// decodeAttachments converts a nullable JSON string pointer into []domain.Attachment.
func decodeAttachments(attJSON *string) []domain.Attachment {
	if attJSON == nil || *attJSON == "" {
		return nil
	}
	var arr []string
	if err := json.Unmarshal([]byte(*attJSON), &arr); err != nil {
		return nil
	}
	out := make([]domain.Attachment, len(arr))
	for i := range arr {
		out[i] = domain.Attachment(arr[i])
	}
	return out
}
