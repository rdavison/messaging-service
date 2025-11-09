package build

import (
	"net"
	"net/http"

	"github.com/rdavison/messaging-service/internal/config"
)

func HTTPServer(h http.Handler, cfg config.Config, baseCtx func(net.Listener) (ctx any)) *http.Server {
	return &http.Server{
		Addr:         cfg.Addr,
		Handler:      h,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
		// BaseContext expects func(net.Listener) context.Context; kept generic here
	}
}
