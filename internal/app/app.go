package app

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/rdavison/messaging-service/internal/api"
	"github.com/rdavison/messaging-service/internal/config"
	"github.com/rdavison/messaging-service/internal/db"
	"github.com/rdavison/messaging-service/internal/processor"
	"github.com/rdavison/messaging-service/internal/provider"
)

type App struct {
	cfg    config.Config
	pool   *pgxpool.Pool
	server *http.Server
	entry  *processor.Entrypoint
	logger *log.Logger
}

func New(ctx context.Context, cfg config.Config, logger *log.Logger) (*App, error) {
	dbCtx, cancel := context.WithTimeout(ctx, cfg.DBConnectTO)
	defer cancel()

	pool, err := db.NewPool(dbCtx, cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}

	h := api.NewRouter(pool)
	srv := &http.Server{
		Addr:         cfg.Addr,
		Handler:      h,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
		ErrorLog:     logger,
	}

	provRouter := processor.SimpleRouter{
		SMS:   provider.TwilioProvider{},
		Email: provider.SendgridProvider{},
	}
	entry := processor.NewEntrypoint(pool, provRouter, logger)

	return &App{
		cfg:    cfg,
		pool:   pool,
		server: srv,
		entry:  entry,
		logger: logger,
	}, nil
}

func (a *App) Start(ctx context.Context) {
	// processor
	go func() {
		if err := a.entry.Run(ctx); err != nil && ctx.Err() == nil {
			a.logger.Printf("processor stopped: %v", err)
		}
	}()

	// http
	go func() {
		a.logger.Printf("listening on %s", a.server.Addr)
		if err := a.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			a.logger.Fatalf("http server: %v", err)
		}
	}()
}

func (a *App) Shutdown(ctx context.Context) {
	// stop HTTP first to drain keep-alives
	if err := a.server.Shutdown(ctx); err != nil {
		a.logger.Printf("server shutdown error: %v", err)
	}
	// DB pool closes after in-flight ops finish
	a.pool.Close()
}

func (a *App) ShutdownTimeout() time.Duration { return a.cfg.ShutdownAfter }
