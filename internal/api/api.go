package api

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"time"
)

func (h *handler) handleConversations(w http.ResponseWriter, r *http.Request, idStr *string) {
	if r.Method != http.MethodGet {
		respondBadRequest(w)
		return
	}
	convs, err := h.getConversations(r.Context(), idStr)
	if err != nil {
		switch {
		case errors.Is(err, ErrBadID):
			respondBadRequest(w)
		case errors.Is(err, ErrNotFound):
			respondNotFound(w, r)
		default:
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, conversationsResponse{Conversations: convs})
}

func (h *handler) handleConversationMessages(w http.ResponseWriter, r *http.Request, convIDStr string) {
	if r.Method != http.MethodGet {
		respondBadRequest(w)
		return
	}
	msgs, err := h.getConversationMessages(r.Context(), convIDStr, 200, 0)
	if err != nil {
		switch {
		case errors.Is(err, ErrBadID):
			respondBadRequest(w)
		case errors.Is(err, ErrNotFound):
			respondNotFound(w, r)
		default:
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, messagesResponse{Messages: msgs})
}

func (h *handler) handleMessagesRoot(w http.ResponseWriter, r *http.Request, idStr *string) {
	if r.Method != http.MethodGet {
		respondBadRequest(w)
		return
	}
	msgs, err := h.getMessages(r.Context(), idStr, 200, 0)
	if err != nil {
		switch {
		case errors.Is(err, ErrBadID):
			respondBadRequest(w)
		case errors.Is(err, ErrNotFound):
			respondNotFound(w, r)
		default:
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, messagesResponse{Messages: msgs})
}

func (h *handler) handleMessagesSMSOutbound(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondBadRequest(w, "method must be POST")
		return
	}
	var req smsOutboundRequest
	if err := decodeJSON(r.Body, &req); err != nil {
		respondBadRequest(w, "json decode: ", err)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	id, err := h.createSMSOutbound(ctx, req)
	if err != nil {
		switch {
		case errors.Is(err, ErrBadType), errors.Is(err, ErrBadTimestamp):
			respondBadRequest(w, err.Error())
		default:
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, idResponse{ID: strconv.FormatInt(id, 10)})
}

func (h *handler) handleMessagesEmailOutbound(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondBadRequest(w)
		return
	}
	var req emailOutboundRequest
	if err := decodeJSON(r.Body, &req); err != nil {
		respondBadRequest(w)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	id, err := h.createEmailOutbound(ctx, req)
	if err != nil {
		if errors.Is(err, ErrBadTimestamp) {
			respondBadRequest(w)
		} else {
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, idResponse{ID: strconv.FormatInt(id, 10)})
}

func (h *handler) handleWebhooksSMSInbound(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondBadRequest(w)
		return
	}
	// decode into a raw map to detect provider key; ops remarshal into typed struct
	var raw map[string]any
	if err := decodeJSON(r.Body, &raw); err != nil {
		respondBadRequest(w)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	id, err := h.createSMSInbound(ctx, raw)
	if err != nil {
		switch {
		case errors.Is(err, ErrNoProvider), errors.Is(err, ErrBadType), errors.Is(err, ErrBadTimestamp):
			respondBadRequest(w)
		default:
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, idResponse{ID: strconv.FormatInt(id, 10)})
}

func (h *handler) handleWebhooksEmailInbound(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondBadRequest(w)
		return
	}
	var raw map[string]any
	if err := decodeJSON(r.Body, &raw); err != nil {
		respondBadRequest(w)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	id, err := h.createEmailInbound(ctx, raw)
	if err != nil {
		switch {
		case errors.Is(err, ErrNoProvider), errors.Is(err, ErrBadTimestamp):
			respondBadRequest(w)
		default:
			respondInternalServerError(w, "db error")
		}
		return
	}
	respondJSON(w, http.StatusOK, idResponse{ID: strconv.FormatInt(id, 10)})
}
