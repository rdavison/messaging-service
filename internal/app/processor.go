package app

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/rdavison/messaging-service/internal/config"
	"github.com/rdavison/messaging-service/internal/db"
	"github.com/rdavison/messaging-service/internal/processor"
)

func DefaultProcessor() {
	logger := log.New(os.Stdout, "", log.LstdFlags)

	cfg := config.MustLoad()

	rootCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	a, err := NewProcessor(rootCtx, cfg, logger)
	if err != nil {
		logger.Fatalf("init: %v", err)
	}
	a.Start(rootCtx)

	<-rootCtx.Done()

	shCtx, cancel := context.WithTimeout(context.Background(), a.ShutdownTimeout())
	defer cancel()

	logger.Println("shutting down...")
	a.Shutdown(shCtx)
}

func NewProcessor(ctx context.Context, cfg config.Config, logger *log.Logger) (*appProcessor, error) {
	dbCtx, cancel := context.WithTimeout(ctx, cfg.DBConnectTO)
	defer cancel()

	pool, err := db.NewPool(dbCtx, cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}

	h := chi.NewRouter()
	h.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	srv := &http.Server{
		Addr:         cfg.Addr,
		Handler:      h,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
		ErrorLog:     logger,
	}

	provRouter := processor.DefaultRouter()
	entry := processor.NewEntrypoint(pool, provRouter, logger)

	return &appProcessor{
		cfg:    cfg,
		pool:   pool,
		server: srv,
		entry:  entry,
		logger: logger,
	}, nil
}

func (a *appProcessor) Start(ctx context.Context) {
	go func() {
		if err := a.entry.Run(ctx); err != nil && ctx.Err() == nil {
			a.logger.Printf("processor stopped: %v", err)
		}
	}()
}
func (a *appProcessor) Shutdown(ctx context.Context) {
	// stop HTTP first to drain keep-alives
	if err := a.server.Shutdown(ctx); err != nil {
		a.logger.Printf("server shutdown error: %v", err)
	}
	// DB pool closes after in-flight ops finish
	a.pool.Close()
}

func (a *appProcessor) ShutdownTimeout() time.Duration { return a.cfg.ShutdownAfter }
