package api

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rdavison/messaging-service/internal/repo"
)

func NewRouter(pool *pgxpool.Pool) http.Handler {
	h := &handler{
		convs: repo.NewConversationRepo(pool),
		msgs:  repo.NewMessageRepo(pool),
	}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	r.Route("/api", func(r chi.Router) {
		r.Route("/messages", func(r chi.Router) {
			r.Get("/", h.handleMessagesIndex)
			r.Get("/{id}", h.handleMessageByID)
			r.Post("/sms", h.handleMessagesSMSOutbound)
			r.Post("/email", h.handleMessagesEmailOutbound)
		})

		r.Route("/webhooks", func(r chi.Router) {
			r.Post("/sms", h.handleWebhooksSMSInbound)
			r.Post("/email", h.handleWebhooksEmailInbound)
		})

		r.Route("/conversations", func(r chi.Router) {
			r.Get("/", h.handleConversationsIndex)
			r.Get("/{id}", h.handleConversationByID)
			r.Get("/{id}/messages", h.handleConversationMessagesChi)
		})
	})

	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	return r
}

func (h *handler) handleMessagesIndex(w http.ResponseWriter, r *http.Request) {
	h.handleMessagesRoot(w, r, nil)
}

func (h *handler) handleMessageByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	h.handleMessagesRoot(w, r, &id)
}

func (h *handler) handleConversationsIndex(w http.ResponseWriter, r *http.Request) {
	h.handleConversations(w, r, nil)
}

func (h *handler) handleConversationByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	h.handleConversations(w, r, &id)
}

func (h *handler) handleConversationMessagesChi(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	h.handleConversationMessages(w, r, id)
}
