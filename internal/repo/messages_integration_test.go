//go:build integration
// +build integration

package repo

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rdavison/messaging-service/internal/domain"
)

func TestInsertOrUpdateByProviderPair_Idempotent(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	defer pool.Close()

	r := NewMessageRepo(pool)
	ctx := context.Background()

	// --- Arrange: create a real conversation row the FK can point to ---
	var convID int64
	err = pool.QueryRow(ctx, `
		INSERT INTO conversations (endpoint_kind, phone_channel, endpoint_source, endpoint_target)
		VALUES ($1, $2, $3, $4)
		RETURNING id
	`, "email", nil, "a@example.com", "b@example.com").Scan(&convID)
	if err != nil {
		t.Fatalf("insert conversation: %v", err)
	}
	// Cleanup: delete conversation (will cascade delete messages)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, `DELETE FROM conversations WHERE id = $1`, convID)
	})

	m := domain.Message{
		ConversationID: convID,
		Source: domain.Endpoint{
			Kind:    domain.EndpointKindEmail,
			Payload: "a@example.com",
		},
		Target: domain.Endpoint{
			Kind:    domain.EndpointKindEmail,
			Payload: "b@example.com",
		},
		Provider: &domain.ProviderRef{
			ID:        "sendgrid",
			MessageID: "prov-1",
		},
		Direction: domain.Inbound,
		SentAt:    time.Now(),
		Body:      "hello",
		Status:    domain.StatusOK,
	}

	id1, err := r.InsertOrUpdateByProviderPair(ctx, m)
	if err != nil {
		t.Fatalf("first upsert: %v", err)
	}
	id2, err := r.InsertOrUpdateByProviderPair(ctx, m)
	if err != nil {
		t.Fatalf("second upsert: %v", err)
	}
	if id1 != id2 {
		t.Fatalf("expected same id, got %d vs %d", id1, id2)
	}
}

func strPtr(s string) *string { return &s }
