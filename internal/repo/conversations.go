package repo

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/rdavison/messaging-service/internal/domain"
)

type ConversationRepo struct {
	Pool *pgxpool.Pool
}

func NewConversationRepo(pool *pgxpool.Pool) *ConversationRepo {
	return &ConversationRepo{Pool: pool}
}

// Get a Conversation by matching against its endpoints. The endpoints
// can be passed in any order. If not found, a new record is created.
// On success, returns the id of the Conversation.
func (r *ConversationRepo) GetOrCreateByEndpoints(
	ctx context.Context,
	source domain.Endpoint,
	target domain.Endpoint,
) (int64, error) {

	kind := source.Kind
	var phoneCh *string
	if source.Kind == domain.EndpointKindPhone {
		if source.Channel == nil {
			return 0, errors.New("phone source missing channel")
		}
		v := source.Channel.String()
		phoneCh = &v
	}

	const sel = `
SELECT id
FROM conversations
WHERE
  endpoint_kind = $1 AND
  phone_channel IS NOT DISTINCT FROM $2 AND
  LEAST(endpoint_source, endpoint_target) = LEAST($3, $4) AND
  GREATEST(endpoint_source, endpoint_target) = GREATEST($3, $4)
`
	var id int64
	err := r.Pool.QueryRow(ctx, sel, kind.String(), phoneCh, source.Payload, target.Payload).Scan(&id)
	if err == nil {
		return id, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return 0, fmt.Errorf("select conversation: %w", err)
	}

	const ins = `
INSERT INTO conversations (
  endpoint_kind,
  phone_channel,
  endpoint_source,
  endpoint_target
) VALUES ($1, $2, $3, $4)
RETURNING id
`
	err = r.Pool.QueryRow(ctx, ins, kind.String(), phoneCh, source.Payload, target.Payload).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("insert conversation: %w", err)
	}
	return id, nil
}

// Look up a Conversation by id.
func (r *ConversationRepo) GetByID(ctx context.Context, id int64) (domain.Conversation, error) {
	const cols = `endpoint_kind, phone_channel, endpoint_source, endpoint_target, created_at, updated_at`
	const q = `SELECT ` + cols + ` FROM conversations WHERE id = $1`
	var (
		kindStr string
		phoneCh *string // nullable
		src     string
		tgt     string
		created time.Time
		updated time.Time
	)
	err := r.Pool.QueryRow(ctx, q, id).Scan(&kindStr, &phoneCh, &src, &tgt, &created, &updated)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.Conversation{}, err
		}
		return domain.Conversation{}, fmt.Errorf("get conversation by id: %w", err)
	}
	kind := domain.EndpointKind(kindStr)
	srcEp, tgtEp, err := domain.DbRowToEndpoints(kind, phoneCh, src, tgt)
	if err != nil {
		return domain.Conversation{}, err
	}
	return domain.Conversation{
		ID:        id,
		Source:    srcEp,
		Target:    tgtEp,
		CreatedAt: created,
		UpdatedAt: updated,
	}, nil
}

// Returns all Conversations.
func (r *ConversationRepo) ListAll(ctx context.Context) ([]domain.Conversation, error) {
	const q = `
SELECT id, endpoint_kind, phone_channel, endpoint_source, endpoint_target, created_at, updated_at
FROM conversations
ORDER BY id ASC`
	rows, err := r.Pool.Query(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("list conversations: %w", err)
	}
	defer rows.Close()

	var out []domain.Conversation
	for rows.Next() {
		var (
			id      int64
			kindStr string
			phoneCh *string
			src     string
			tgt     string
			created time.Time
			updated time.Time
		)
		if err := rows.Scan(&id, &kindStr, &phoneCh, &src, &tgt, &created, &updated); err != nil {
			return nil, err
		}
		kind := domain.EndpointKind(kindStr)
		srcEp, tgtEp, err := domain.DbRowToEndpoints(kind, phoneCh, src, tgt)
		if err != nil {
			return nil, err
		}
		out = append(out, domain.Conversation{
			ID:        id,
			Source:    srcEp,
			Target:    tgtEp,
			CreatedAt: created,
			UpdatedAt: updated,
		})
	}
	return out, rows.Err()
}

// Checks to see if a Conversation exists with a given id.
func (r *ConversationRepo) Exists(ctx context.Context, id int64) (bool, error) {
	const q = `SELECT id FROM conversations WHERE id = $1`
	var got string
	err := r.Pool.QueryRow(ctx, q, id).Scan(&got)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
