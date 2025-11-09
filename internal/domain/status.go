package domain

type Status string

const (
	StatusOutbox Status = "outbox"
	StatusRetry  Status = "retry"
	StatusOK     Status = "ok"
	StatusFailed Status = "failed"
)

func IsStatusTerminal(status Status) bool {
	return status == StatusOK || status == StatusFailed
}
