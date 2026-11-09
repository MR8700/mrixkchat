package config

import (
	"os"
	"strconv"
)

// Config holds the server runtime configuration.
type Config struct {
	Port              string
	DatabaseURL       string
	RedisURL          string
	MaxDevicesPerUser int
	StorageEndpoint   string
	StorageBucket     string
	JWTSecret         string
}

// LoadConfig loads configuration from environment variables with safe defaults.
func LoadConfig() *Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://mrixk_admin:mrixk_secure_password_2026@localhost:5432/mrixk?sslmode=disable"
	}

	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379/0"
	}

	maxDevices := 3
	if val := os.Getenv("MAX_DEVICES_PER_USER"); val != "" {
		if parsed, err := strconv.Atoi(val); err == nil && parsed > 0 {
			maxDevices = parsed
		}
	}

	jwtSecret := os.Getenv("JWT_SIGNING_KEY")
	if jwtSecret == "" {
		jwtSecret = "mrixk_jwt_dev_secret_2026_super_secure"
	}

	return &Config{
		Port:              port,
		DatabaseURL:       dbURL,
		RedisURL:          redisURL,
		MaxDevicesPerUser: maxDevices,
		StorageEndpoint:   os.Getenv("STORAGE_ENDPOINT"),
		StorageBucket:     os.Getenv("STORAGE_BUCKET"),
		JWTSecret:         jwtSecret,
	}
}
