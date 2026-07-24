#!/usr/bin/env bash
set -euo pipefail

echo "================================================="
echo "   Setting up Local Multi-Model AI Specialist Team"
echo "================================================="

# 1. Check for Ollama
if ! command -v ollama &> /dev/null; then
    echo "[+] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "[✓] Ollama is installed."
fi

# 2. Configure Ollama Environment for CPU/RAM optimization
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_NUM_PARALLEL=1

echo "[+] Pulling specialist models into local library..."
echo "--> Router (Qwen 2.5 1.5B)..."
ollama pull qwen2.5:1.5b

echo "--> Coding Specialist (Qwen 2.5 Coder 7B Q4)..."
ollama pull qwen2.5-coder:7b-instruct-q4_K_M

echo "--> General Worker (Qwen 2.5 7B Q4)..."
ollama pull qwen2.5:7b-instruct-q4_K_M

echo "--> Verifier (Qwen 2.5 3B)..."
ollama pull qwen2.5:3b

# 3. Check for Docker & Docker Compose
if command -v docker &> /dev/null; then
    echo "[+] Launching n8n via Docker Compose..."
    if docker compose version &> /dev/null; then
        docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        echo "[!] Docker Compose not found. Please install docker-compose or the docker-compose-plugin."
        exit 1
    fi
    echo "[✓] n8n container started successfully."
else
    echo "[!] Docker not detected. Please install Docker and Docker Compose."
    exit 1
fi

echo "================================================="
echo " Setup Complete!"
echo " Ollama API running at: http://localhost:11434"
echo " Access n8n UI at:      http://localhost:5678"
echo "================================================="
