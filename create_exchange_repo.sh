#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-./centralized-exchange-mvp}"
echo "Creating project at: $ROOT"
mkdir -p "$ROOT"
cd "$ROOT"

# Write README
cat > README.md <<'EOF'
# Centralized Exchange MVP — Starter Template

This repository is a starter scaffold for a centralized exchange MVP (Binance-like).
It contains:

- A Go backend with an embedded matching engine and JSON-lines WAL
- A minimal React + Vite frontend with a modern landing page and trading UI
- Docker Compose for local development (Postgres, Redis, backend, frontend)
- CI workflow example

Important safety notes:
- This code is an educational MVP and is NOT production-ready. Do NOT accept or hold real funds with it.
- Before production you must: perform security audits & pentests, replace naive WAL with robust durability and HA, implement secure key management/HSMs for custody, KYC/AML, and thorough monitoring.

Quickstart (local, dev):
1. Copy `.env.example` -> `.env` and adjust secrets.
2. docker-compose up --build
3. Backend API: http://localhost:4000
4. Frontend: http://localhost:5173

See backend/ and frontend/ for implementation details.
EOF

# .env.example
cat > .env.example <<'EOF'
# Backend
PORT=4000
DATABASE_URL=postgres://exchange:exchange@postgres:5432/exchange?sslmode=disable
REDIS_URL=redis://redis:6379
JWT_SECRET=replace-with-a-long-random-secret
WAL_DIR=/var/lib/exchange/wal
WAL_FILE=orders.wal

# Frontend
VITE_API_URL=http://localhost:4000
EOF

# docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: exchange
      POSTGRES_PASSWORD: exchange
      POSTGRES_DB: exchange
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  backend:
    build: ./backend
    env_file:
      - .env
    ports:
      - "4000:4000"
    depends_on:
      - postgres
      - redis
    volumes:
      - waldata:/var/lib/exchange/wal

  frontend:
    build: ./frontend
    env_file:
      - .env
    ports:
      - "5173:5173"
    depends_on:
      - backend

volumes:
  pgdata:
  waldata:
EOF

# Minimal CI workflow
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: 1.21
      - name: Build backend
        run: |
          cd backend
          go build ./cmd/exchange
      - name: Build frontend
        run: |
          cd frontend
          npm ci
          npm run build
EOF

echo "Scaffold created at $ROOT"
echo

echo "Next steps (local):"
echo "  cd $ROOT"
echo "  git init"
echo "  git add ."
echo "  git commit -m \"Initial commit: centralized-exchange-mvp\""
echo "  git branch -M main"
echo

echo "Then create a repository on GitHub (do NOT initialize with README):"
echo "  - Using web UI: https://github.com/new (create repo 'centralized-exchange-mvp' under your account)"
echo "  - OR using GitHub CLI:"
echo "      gh repo create Mudays2022/centralized-exchange-mvp --public --confirm"
echo

echo "After repo exists, push:"
echo "  git remote add origin git@github.com:Mudays2022/centralized-exchange-mvp.git"
echo "  git push -u origin main"
echo

echo "Make it a template via web UI: Settings -> General -> 'Template repository' (check) -> Save"
echo "Or using gh:"
echo "  gh api -X PATCH /repos/Mudays2022/centralized-exchange-mvp -f is_template=true"
echo

echo "To run locally with Docker Compose:"
echo "  cp .env.example .env    # adjust values"
echo "  docker-compose up --build"