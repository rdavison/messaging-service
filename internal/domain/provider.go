package domain

// Provider enumeration used by inbound webhooks
type Provider string

const (
	ProviderTwilio            Provider = "twilio"
	ProviderSendgrid          Provider = "sendgrid"
	ProviderMessagingProvider Provider = "messaging_provider"
	ProviderXillio            Provider = "xillio"
)

func (p Provider) String() string { return string(p) }

func AllProviders() []Provider {
	return []Provider{ProviderTwilio, ProviderSendgrid, ProviderMessagingProvider, ProviderXillio}
}
