#!/usr/bin/env bash
set -euo pipefail

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

echo "================================================="
echo " Setup Complete!"
echo " Ollama API running at: http://localhost:11434"
echo " Access n8n UI at:      http://localhost:5678"
echo "================================================="
