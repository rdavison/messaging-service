package config

import (
	"os"
	"time"
)

type Config struct {
	DatabaseURL   string
	Addr          string
	ReadTimeout   time.Duration
	WriteTimeout  time.Duration
	IdleTimeout   time.Duration
	ShutdownAfter time.Duration
	DBConnectTO   time.Duration
}

func getenvWithDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getenvWithDefaultDuration(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}

func Load() (Config, error) {
	cfg := Config{
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		Addr:          getenvWithDefault("ADDR", ":8080"),
		ReadTimeout:   getenvWithDefaultDuration("READ_TIMEOUT", 5*time.Second),
		WriteTimeout:  getenvWithDefaultDuration("WRITE_TIMEOUT", 10*time.Second),
		IdleTimeout:   getenvWithDefaultDuration("IDLE_TIMEOUT", 60*time.Second),
		ShutdownAfter: getenvWithDefaultDuration("SHUTDOWN_TIMEOUT", 15*time.Second),
		DBConnectTO:   getenvWithDefaultDuration("DB_CONNECT_TIMEOUT", 5*time.Second),
	}
	return cfg, nil
}

func MustLoad() Config {
	cfg, _ := Load()
	if cfg.DatabaseURL == "" {
		panic("DATABASE_URL is required, e.g. postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable")
	}
	return cfg
}
