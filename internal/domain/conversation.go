package domain

import (
	"encoding/json"
	"fmt"
	"time"
)

// JSON shape for Conversation.to_json equivalent:
//
//	{
//	  "id": "123",
//	  "endpoint_kind": "phone",
//	  "channel": "sms",               // present only if kind == phone
//	  "endpoint_source": "+1201...",
//	  "endpoint_target": "+1804..."
//	}
type ConversationJSON struct {
	ID           string  `json:"id"`
	EndpointKind string  `json:"endpoint_kind"`
	Channel      *string `json:"channel,omitempty"`
	EndpointSrc  string  `json:"endpoint_source"`
	EndpointTgt  string  `json:"endpoint_target"`
}

type Conversation struct {
	ID        int64
	Source    Endpoint
	Target    Endpoint
	CreatedAt time.Time
	UpdatedAt time.Time
}

func (c Conversation) MarshalJSON() ([]byte, error) {
	var ch *string
	if c.Source.Kind == EndpointKindPhone && c.Source.Channel != nil {
		v := c.Source.Channel.String()
		ch = &v
	}
	out := ConversationJSON{
		ID:           fmt.Sprintf("%d", c.ID),
		EndpointKind: c.Source.Kind.String(), // OCaml uses source.kind
		Channel:      ch,
		EndpointSrc:  c.Source.Payload,
		EndpointTgt:  c.Target.Payload,
	}
	return json.Marshal(out)
}
