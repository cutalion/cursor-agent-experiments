# LiteLLM API Gateway

This project provides a secure, modular, and observable infrastructure to manage access to multiple AI API providers using LiteLLM and Caddy.

## Prerequisites

- Docker
- Docker Compose

## Quick Start (Development)

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

2. Start the services in development mode:
   ```bash
   ./scripts/start-dev.sh
   ```
   Or manually:
   ```bash
   docker-compose up -d
   ```

3. Test the gateway:
   ```bash
   curl -X POST http://localhost:8080/chat/completions \
     -H "Authorization: Bearer sk-dev-key" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "gpt-3.5-turbo",
       "messages": [{"role": "user", "content": "Hello!"}]
     }'
   ```

## Production Deployment

For production, you should not use the development override.

1. Configure your domain and email in `.env`:
   ```env
   DOMAIN=api.yourdomain.com
   ACME_EMAIL=admin@yourdomain.com
   LITELLM_MASTER_KEY=your-secure-master-key
   ```

2. Start the services without the development override:
   ```bash
   ./scripts/start-prod.sh
   ```
   Or manually:
   ```bash
   docker-compose -f docker-compose.yml up -d
   ```

## Configuration

- **LiteLLM**: Edit `litellm-config.yaml` to add or remove models and providers.
- **Caddy**: Edit `Caddyfile` (production) or `Caddyfile.dev` (development) for routing and TLS configuration.
