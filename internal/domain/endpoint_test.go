package domain

import "testing"

func TestEndpointKindString(t *testing.T) {
	cases := []struct {
		k    EndpointKind
		want string
	}{
		{EndpointKindPhone, "phone"},
		{EndpointKindEmail, "email"},
	}
	for _, c := range cases {
		if got := c.k.String(); got != c.want {
			t.Fatalf("String(%v) = %q, want %q", c.k, got, c.want)
		}
	}
}
