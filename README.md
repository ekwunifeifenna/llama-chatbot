# llama-chatbot

# AI Chatbot API

Production-ready chatbot service with GPU acceleration.

## Features
- Mistral-7B model support
- Session management
- Rate limiting
- Prometheus metrics
- Docker/Kubernetes ready

## Quick Start

```bash
docker compose up -d --build

# Test API
curl -X POST http://localhost:8080/chat \
  -H "X-API-Key: your-secure-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "123", "message": "Explain quantum computing"}'