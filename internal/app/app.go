package app

import (
	"context"
	"log"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/rdavison/messaging-service/internal/config"
	"github.com/rdavison/messaging-service/internal/processor"
)

type App interface {
	Start(context.Context)
	Shutdown(context.Context)
	ShutdownTimeout(context.Context)
}

type appApiserver struct {
	cfg    config.Config
	pool   *pgxpool.Pool
	server *http.Server
	entry  *processor.Entrypoint
	logger *log.Logger
}

type appProcessor struct {
	cfg    config.Config
	pool   *pgxpool.Pool
	server *http.Server
	entry  *processor.Entrypoint
	logger *log.Logger
}
