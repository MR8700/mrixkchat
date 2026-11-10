package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"mrixk.io/mrixk/backend/internal/api"
	"mrixk.io/mrixk/backend/internal/config"
	"mrixk.io/mrixk/backend/internal/database"
	"mrixk.io/mrixk/backend/internal/devices"
	"mrixk.io/mrixk/backend/internal/identity"
	"mrixk.io/mrixk/backend/internal/messaging"
)

func main() {
	cfg := config.LoadConfig()

	log.Printf("[MRixk Server] Initializing modular monolith...")
	log.Printf("[MRixk Server] Max active devices per user: %d", cfg.MaxDevicesPerUser)

	repo := database.NewMemoryRepository(cfg.MaxDevicesPerUser)
	if cfg.DataFilePath != "" {
		if err := repo.SetStoragePath(cfg.DataFilePath); err != nil {
			log.Printf("[MRixk Server] Notice: Initialized new durable state at %s", cfg.DataFilePath)
		} else {
			log.Printf("[MRixk Server] Durable persistence loaded successfully from: %s", cfg.DataFilePath)
		}
	}
	idService := identity.NewService(repo)
	deviceService := devices.NewService(repo)
	msgService := messaging.NewService(repo)

	server := api.NewServer(idService, deviceService, msgService, repo)

	httpServer := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      server,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("[MRixk Server] Listening on http://0.0.0.0:%s", cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[MRixk Server] Fatal HTTP server error: %v", err)
		}
	}()

	<-stopChan
	log.Printf("[MRixk Server] Gracefully shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(ctx); err != nil {
		log.Printf("[MRixk Server] Forced shutdown error: %v", err)
	}

	if cfg.DataFilePath != "" {
		if err := repo.SaveToFile(cfg.DataFilePath); err != nil {
			log.Printf("[MRixk Server] Error persisting state on shutdown: %v", err)
		} else {
			log.Printf("[MRixk Server] State successfully persisted to: %s", cfg.DataFilePath)
		}
	}
	log.Printf("[MRixk Server] Server terminated cleanly.")
}
