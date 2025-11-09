package build

import (
	"github.com/rdavison/messaging-service/internal/processor"
	"github.com/rdavison/messaging-service/internal/provider"
)

// ProviderRouter centralizes how providers are wired.
func ProviderRouter() processor.SimpleRouter {
	return processor.SimpleRouter{
		SMS:   provider.TwilioProvider{},
		Email: provider.SendgridProvider{},
	}
}
