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
export OLLAMA_FLASH_ATTENTION=1 # added to reduce VRAM consumption during long-context operations
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1

echo "[+] Pulling specialist models into local library..."
echo "--> Router (Qwen 3.5 2B)..."
ollama pull qwen3.5:2b

echo " --> Specialized Coder Model (Qwen 2.5 Coder 7B)... "
ollama pull qwen2.5-coder:7b-instruct

echo " --> Verifier (Qwen 3.5 4B)... "
ollama pull qwen3.5:4b

echo " --> Deep Debugger (DeepSeek R1 7B)... "
ollama pull deepseek-r1:7b


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

# Wait for n8n to finish starting before importing the workflow.
echo "[+] Waiting for n8n to become ready..."
ready=false
for ((attempt = 1; attempt <= 60; attempt++)); do
    if curl -fsS http://localhost:5678/healthz >/dev/null; then
        ready=true
        break
    fi
    sleep 2
done

if [[ "$ready" != true ]]; then
    echo "[!] n8n did not become ready within 120 seconds. Check 'docker compose logs n8n'."
    exit 1
fi

# Keep the marker in the persistent n8n data volume to import only once.
echo "[+] Importing workflow.json if this is the first setup..."
docker exec -u node n8n_specialists sh -c '
    marker=/home/node/.n8n/workflow-imported
    if [ -f "$marker" ]; then
        echo "[i] Workflow was already imported; skipping."
    else
        n8n import:workflow --input=/files/workflow.json
        touch "$marker"
    fi
'

echo "================================================="
echo " Setup Complete!"
echo " Ollama API running at: http://localhost:11434"
echo " Access n8n UI at:      http://localhost:5678"
echo "================================================="
