# ==============================================================================
# MRixk — Fullstack All-in-One Cloud Deployment (Backend Go + Client PWA Web)
# ==============================================================================

# Étape 1 : Compilation du binaire Go
FROM docker.io/library/golang:1.22-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git gcc musl-dev

COPY go.mod go.sum ./
RUN go mod download
COPY backend ./backend
COPY packages ./packages

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/bin/mrixk-server ./backend/cmd/server

# Étape 2 : Image d'exécution ultra-légère et sécurisée
FROM docker.io/library/alpine:3.19

WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata && mkdir -p /app/data /app/web

COPY --from=builder /app/bin/mrixk-server /app/mrixk-server

# Embarque automatiquement le client PWA Web Flutter
COPY apps/client_flutter/build/web /app/web

EXPOSE 8080 10000

ENV PORT=8080
ENV STATIC_WEB_DIR=/app/web
ENV DATA_FILE_PATH=/app/data/mrixk_state.json
ENV APP_ENV=production
ENV JWT_SIGNING_KEY=mrixk_default_jwt_signing_secret_railway_2026

ENTRYPOINT ["/app/mrixk-server"]
