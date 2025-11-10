package app

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rdavison/messaging-service/internal/api"
	"github.com/rdavison/messaging-service/internal/config"
	"github.com/rdavison/messaging-service/internal/db"
	"github.com/rdavison/messaging-service/internal/processor"
)

func DefaultAPIServer() {
	logger := log.New(os.Stdout, "", log.LstdFlags)

	cfg := config.MustLoad()

	rootCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	a, err := NewAPIServer(rootCtx, cfg, logger)
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

func NewAPIServer(ctx context.Context, cfg config.Config, logger *log.Logger) (*appApiserver, error) {
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

	provRouter := processor.DefaultRouter()
	entry := processor.NewEntrypoint(pool, provRouter, logger)

	return &appApiserver{
		cfg:    cfg,
		pool:   pool,
		server: srv,
		entry:  entry,
		logger: logger,
	}, nil
}

func (a *appApiserver) Start(ctx context.Context) {
	go func() {
		a.logger.Printf("listening on %s", a.server.Addr)
		if err := a.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			a.logger.Fatalf("http server: %v", err)
		}
	}()
}

func (a *appApiserver) Shutdown(ctx context.Context) {
	// stop HTTP first to drain keep-alives
	if err := a.server.Shutdown(ctx); err != nil {
		a.logger.Printf("server shutdown error: %v", err)
	}
	// DB pool closes after in-flight ops finish
	a.pool.Close()
}

func (a *appApiserver) ShutdownTimeout() time.Duration { return a.cfg.ShutdownAfter }
