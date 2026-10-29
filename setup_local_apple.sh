#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "================================================="
echo " Setting up Local AI Specialist Team for Apple Silicon"
echo "================================================="

# This setup targets Apple Silicon Macs with 16 GB of unified memory.
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "[!] This script is for macOS. Use setup_local_team.sh on Linux."
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "[!] Apple Silicon was not detected. This script expects an M-series Mac."
    exit 1
fi

# Install Ollama with its official macOS/Linux installer if the CLI is missing.
if ! command -v ollama &> /dev/null; then
    echo "[+] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "[✓] Ollama is installed."
fi

# Keep inference serialized so models do not compete for unified memory.
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1

echo "[+] Checking whether the Ollama server is running..."
if ollama list >/dev/null 2>&1; then
    echo "[✓] Ollama server is already running."
else
    ollama_log_path="${TMPDIR:-/tmp}/ollama-local-apple.log"
    echo "[+] Starting Ollama server..."
    nohup ollama serve >"$ollama_log_path" 2>&1 &

    ollama_ready=false
    for ((attempt = 1; attempt <= 30; attempt++)); do
        if ollama list >/dev/null 2>&1; then
            ollama_ready=true
            break
        fi
        sleep 2
    done

    if [[ "$ollama_ready" != true ]]; then
        echo "[!] Ollama did not become ready within 60 seconds. Check: $ollama_log_path"
        exit 1
    fi
    echo "[✓] Ollama server started successfully."
fi

echo "[+] Pulling the current specialist models..."
echo "--> Router (Qwen 3.5 2B)..."
ollama pull qwen3.5:2b

echo "--> Specialized Coder (Qwen 2.5 Coder 7B)..."
ollama pull qwen2.5-coder:7b-instruct

echo "--> Verifier and General Worker (Qwen 3.5 4B)..."
ollama pull qwen3.5:4b

echo "--> Deep Debugger (DeepSeek R1 7B)..."
ollama pull deepseek-r1:7b

# Start n8n if Docker Compose is available.
if ! command -v docker &> /dev/null; then
    echo "[!] Docker was not detected. Install and start Docker Desktop, then run this script again."
    exit 1
fi

echo "[+] Launching n8n via Docker Compose..."
if docker compose version &> /dev/null; then
    docker compose up -d
elif command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    echo "[!] Docker Compose was not found. Install Docker Desktop or Docker Compose."
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
        n8n import:workflow --input=/tmp/workflow.json
        touch "$marker"
    fi
'

echo "================================================="
echo " Setup Complete!"
echo " Ollama API running at: http://localhost:11434"
echo " Access n8n UI at:      http://localhost:5678"
echo "================================================="
