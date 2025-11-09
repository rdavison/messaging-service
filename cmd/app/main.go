package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/rdavison/messaging-service/internal/app"
	"github.com/rdavison/messaging-service/internal/config"
)

func main() {
	logger := log.New(os.Stdout, "", log.LstdFlags)

	cfg := config.MustLoad()

	rootCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	a, err := app.New(rootCtx, cfg, logger)
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
