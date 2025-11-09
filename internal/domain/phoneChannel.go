package domain

type PhoneChannel string

const (
	PhoneChannelSMS PhoneChannel = "sms"
	PhoneChannelMMS PhoneChannel = "mms"
)

func (c PhoneChannel) String() string { return string(c) }
