package processor

import (
	"errors"
	"fmt"

	"github.com/rdavison/messaging-service/internal/domain"
	"github.com/rdavison/messaging-service/internal/provider"
)

// Router selects a concrete outbound provider for a message.
type Router interface {
	ChooseProvider(m domain.Message) (provider.Provider, error)
}

// SimpleRouter chooses based on message EndpointKind.
type SimpleRouter struct {
	SMS   provider.Provider
	Email provider.Provider
}

func (r SimpleRouter) ChooseProvider(m domain.Message) (provider.Provider, error) {
	switch {
	// phone → phone => SMS/MMS provider
	case m.Source.Kind == domain.EndpointKindPhone && m.Target.Kind == domain.EndpointKindPhone:
		if r.SMS != nil {
			return r.SMS, nil
		}
		return nil, errors.New("no SMS provider configured")

	// email → email => Email provider
	case m.Source.Kind == domain.EndpointKindEmail && m.Target.Kind == domain.EndpointKindEmail:
		if r.Email != nil {
			return r.Email, nil
		}
		return nil, errors.New("no email provider configured")

	// mixed kinds are not supported by this simple router
	default:
		return nil, fmt.Errorf("no provider for source -> target: %s -> %s", m.Source.Kind, m.Target.Kind)
	}
}
