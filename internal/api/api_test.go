package api

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDecodeJSON_OK(t *testing.T) {
	type req struct {
		A int `json:"a"`
	}
	var r req
	body := bytes.NewBufferString(`{"a":1}`)
	if err := decodeJSON(io.NopCloser(bytes.NewReader(body.Bytes())), &r); err != nil {
		t.Fatalf("decode err: %v", err)
	}
	if r.A != 1 {
		t.Fatalf("want 1 got %d", r.A)
	}
}

func TestDecodeJSON_UnknownField(t *testing.T) {
	type req struct {
		A int `json:"a"`
	}
	var r req
	body := bytes.NewBufferString(`{"a":1,"x":2}`)
	err := decodeJSON(io.NopCloser(bytes.NewReader(body.Bytes())), &r)
	if err == nil {
		t.Fatalf("expected error on unknown field")
	}
}

func TestRespondJSON(t *testing.T) {
	rr := httptest.NewRecorder()
	respondJSON(rr, http.StatusTeapot, map[string]string{"x": "y"})
	if rr.Code != http.StatusTeapot {
		t.Fatalf("code %d", rr.Code)
	}
	var m map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &m); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if m["x"] != "y" {
		t.Fatalf("bad body: %v", m)
	}
}
