# ==============================================================================
# MRixk — Dockerfile pour Déploiement Cloud (Render, Fly, VPS)
# ==============================================================================

# Étape 1 : Compilation du binaire Go
FROM golang:1.22-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git gcc musl-dev

COPY go.mod ./
COPY backend ./backend
COPY packages ./packages

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/bin/mrixk-server ./backend/cmd/server

# Étape 2 : Image d'exécution ultra-légère et sécurisée
FROM alpine:3.19

WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata && mkdir -p /app/data

COPY --from=builder /app/bin/mrixk-server /app/mrixk-server

EXPOSE 10000 8080

ENV PORT=10000
ENV DATA_FILE_PATH=/app/data/mrixk_state.json
ENV APP_ENV=production

ENTRYPOINT ["/app/mrixk-server"]
