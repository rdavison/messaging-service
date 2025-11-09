package domain

import (
	"errors"
	"fmt"
	"strings"
)

type EndpointKind string

const (
	EndpointKindEmail EndpointKind = "email"
	EndpointKindPhone EndpointKind = "phone"
)

func (k EndpointKind) String() string { return string(k) }

// If Kind is "phone", Channel is required; for "email", Channel must be nil.
type Endpoint struct {
	Kind    EndpointKind  `json:"-"`
	Channel *PhoneChannel `json:"-"` // only set when Kind == phone
	Payload string        `json:"-"` // email address or E.164 number
}

func (e Endpoint) PhoneChannel() *PhoneChannel { return e.Channel }

func (e Endpoint) MustBe(kind EndpointKind) error {
	if e.Kind != kind {
		return fmt.Errorf("endpoint kind mismatch: got %q want %q", e.Kind, kind)
	}
	return nil
}

// Construct endpoints from DB row columns.
func DbRowToEndpoints(kind EndpointKind, phoneChNullable *string, src, tgt string) (Endpoint, Endpoint, error) {
	var ch *PhoneChannel
	if kind == EndpointKindPhone {
		if phoneChNullable == nil {
			return Endpoint{}, Endpoint{}, errors.New("phone endpoint requires phone_channel")
		}
		pc := PhoneChannel(strings.ToLower(*phoneChNullable))
		switch pc {
		case PhoneChannelSMS, PhoneChannelMMS:
			ch = &pc
		default:
			return Endpoint{}, Endpoint{}, fmt.Errorf("unknown phone_channel: %q", *phoneChNullable)
		}
	} else {
		ch = nil
	}
	srcEp := Endpoint{Kind: kind, Channel: ch, Payload: src}
	tgtEp := Endpoint{Kind: kind, Channel: ch, Payload: tgt}
	return srcEp, tgtEp, nil
}
