package build

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rdavison/messaging-service/internal/api"
)

func HTTPHandler(pool *pgxpool.Pool) http.Handler {
	return api.NewRouter(pool)
}
