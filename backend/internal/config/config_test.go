package config

import (
	"testing"
)

func TestConfigEphemeralJWTKeyInProduction(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("JWT_SIGNING_KEY", "")

	cfg := LoadConfig()
	if cfg.JWTSecret == "" {
		t.Fatal("expected non-empty JWTSecret generated for production")
	}
	if len(cfg.JWTSecret) < 32 {
		t.Fatalf("expected robust 256-bit hex secret, got %s", cfg.JWTSecret)
	}
}

func TestConfigExplicitJWTKey(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("JWT_SIGNING_KEY", "explicit_custom_production_key_123456789")

	cfg := LoadConfig()
	if cfg.JWTSecret != "explicit_custom_production_key_123456789" {
		t.Fatalf("expected explicit key to be used, got %s", cfg.JWTSecret)
	}
}
