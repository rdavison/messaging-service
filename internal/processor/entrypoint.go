package processor

import (
	"context"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/rdavison/messaging-service/internal/repo"
)

type Entrypoint struct {
	pool   *pgxpool.Pool
	msgs   *repo.MessageRepo
	router Router
	logger *log.Logger
	period time.Duration
}

func NewEntrypoint(pool *pgxpool.Pool, router Router, logger *log.Logger) *Entrypoint {
	if logger == nil {
		logger = log.Default()
	}
	return &Entrypoint{
		pool:   pool,
		msgs:   repo.NewMessageRepo(pool),
		router: router,
		logger: logger,
		period: 2 * time.Second,
	}
}

func (e *Entrypoint) Run(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		e.logger.Printf("Polling for unprocessed messages")
		msgs, err := e.msgs.PollOutboxOrRetry(ctx, 200) // oldest first
		if err != nil {
			e.logger.Printf("poll error: %v", err)
			time.Sleep(e.period)
			continue
		}
		e.logger.Printf("Got %d unprocessed messages", len(msgs))

		for i, m := range msgs {
			e.logger.Printf("Processing message %d/%d (id=%d)", i+1, len(msgs), m.ID)
			status, err := e.TransitionStatus(ctx, m.ID)
			if err != nil {
				e.logger.Printf("transition error id=%d: %v", m.ID, err)
				continue
			}
			e.logger.Printf("New status for message id=%d => %s", m.ID, status)
		}

		time.Sleep(e.period)
	}
}
