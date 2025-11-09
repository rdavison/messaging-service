package api

import (
	"github.com/rdavison/messaging-service/internal/domain"
)

// Helper function to find a the provider metadata inside a map[string]any. Returns the
// first one detected.
func extractProviderID(raw map[string]any) (domain.Provider, string, bool) {
	for _, p := range domain.AllProviders() {
		k := p.String() + "_id"
		if v, ok := raw[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return p, s, true
			}
		}
	}
	return "", "", false
}
