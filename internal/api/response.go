package api

import (
	"encoding/json"
	"fmt"
	"net/http"
)

type errorResponse struct {
	Error string `json:"error"`
}

func respondJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func respondBadRequest(w http.ResponseWriter, msg ...any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusBadRequest)
	if len(msg) == 0 {
		_ = json.NewEncoder(w).Encode(errorResponse{Error: "bad request"})
		return
	}
	_ = json.NewEncoder(w).Encode(errorResponse{
		Error: fmt.Sprint(msg...),
	})
}

func respondInternalServerError(w http.ResponseWriter, msg string) {
	http.Error(w, msg, http.StatusInternalServerError)
}

func respondNotFound(w http.ResponseWriter, r *http.Request) {
	http.NotFound(w, r)
}
