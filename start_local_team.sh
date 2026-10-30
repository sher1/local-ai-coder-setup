#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

OS_NAME="$(uname -s)"
if [[ "$OS_NAME" != "Darwin" && "$OS_NAME" != "Linux" ]]; then
    echo "[!] This script supports macOS and Linux only."
    exit 1
fi

echo "================================================="
echo "   Starting Local Multi-Model AI Specialist Team"
echo "================================================="

if ! command -v ollama &> /dev/null; then
    echo "[+] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "[✓] Ollama is installed."
fi

# Limit model concurrency to fit the project's 16 GB Apple and 32 GB Linux setups.
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1

echo "[+] Checking whether the Ollama server is running..."
if ollama list >/dev/null 2>&1; then
    if [[ "$OS_NAME" == "Darwin" ]]; then
        echo "[+] Restarting the Ollama app so it uses this script's settings..."
        if ! osascript -e 'tell application "Ollama" to quit' >/dev/null 2>&1; then
            echo "[!] Ollama is responding, but the Ollama macOS app could not be quit."
            echo "[!] Quit Ollama manually, then run this script again so its settings take effect."
            exit 1
        fi

        ollama_stopped=false
        for ((attempt = 1; attempt <= 30; attempt++)); do
            if ! ollama list >/dev/null 2>&1; then
                ollama_stopped=true
                break
            fi
            sleep 2
        done

        if [[ "$ollama_stopped" != true ]]; then
            echo "[!] The existing Ollama server did not stop within 60 seconds."
            echo "[!] Quit Ollama manually, then run this script again."
            exit 1
        fi
    else
        echo "[✓] Ollama server is already running."
    fi
fi

if ! ollama list >/dev/null 2>&1; then
    ollama_log_path="${TMPDIR:-/tmp}/ollama-local-team.log"
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

if ! command -v docker &> /dev/null; then
    echo "[!] Docker was not detected. Install and start Docker Desktop or Docker Engine, then run this script again."
    exit 1
fi

echo "[+] Launching n8n via Docker Compose..."
if docker compose version &> /dev/null; then
    docker compose up -d
elif command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    echo "[!] Docker Compose was not found. Install Docker Compose and run this script again."
    exit 1
fi

echo "[+] Waiting for n8n to become ready..."
n8n_ready=false
for ((attempt = 1; attempt <= 60; attempt++)); do
    if curl -fsS http://localhost:5678/healthz >/dev/null; then
        n8n_ready=true
        break
    fi
    sleep 2
done

if [[ "$n8n_ready" != true ]]; then
    echo "[!] n8n did not become ready within 120 seconds. Check 'docker compose logs n8n'."
    exit 1
fi

echo "[+] Importing workflow.json if this is the first setup..."
docker exec -u node n8n_specialists sh -c '
    workflow_id=8f6dd7a1-9724-4ea5-8a7c-733f6b5d6c20
    if n8n export:workflow --id="$workflow_id" --output=/dev/null >/dev/null 2>&1; then
        echo "[i] Workflow already exists in n8n; skipping import."
    else
        n8n import:workflow --input=/tmp/workflow.json
        n8n export:workflow --id="$workflow_id" --output=/dev/null >/dev/null
        echo "[✓] Workflow imported and verified."
    fi
'

echo "================================================="
echo " Setup Complete!"
echo " Ollama API running at: http://localhost:11434"
echo " Access n8n UI at:      http://localhost:5678"
echo "================================================="
