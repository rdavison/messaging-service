package domain

import "testing"

func TestAllProvidersContainsKnown(t *testing.T) {
	ps := AllProviders()
	if len(ps) == 0 {
		t.Fatal("AllProviders returned none")
	}
	foundTwilio, foundSendgrid := false, false
	for _, p := range ps {
		switch p {
		case Provider("twilio"):
			foundTwilio = true
		case Provider("sendgrid"):
			foundSendgrid = true
		}
	}
	if !foundTwilio || !foundSendgrid {
		t.Fatalf("expected twilio & sendgrid in AllProviders; got %v", ps)
	}
}
