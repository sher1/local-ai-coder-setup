#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

stop_failed=false

echo "[+] Stopping n8n..."
if command -v docker &> /dev/null; then
    if docker compose version &> /dev/null; then
        if docker compose stop n8n; then
            echo "[✓] n8n stopped."
        else
            echo "[!] Could not stop n8n with Docker Compose."
            stop_failed=true
        fi
    elif command -v docker-compose &> /dev/null; then
        if docker-compose stop n8n; then
            echo "[✓] n8n stopped."
        else
            echo "[!] Could not stop n8n with Docker Compose."
            stop_failed=true
        fi
    elif docker inspect n8n_specialists &> /dev/null; then
        if docker stop n8n_specialists; then
            echo "[✓] n8n stopped."
        else
            echo "[!] Could not stop the n8n container."
            stop_failed=true
        fi
    else
        echo "[i] Docker Compose is unavailable; no n8n container was stopped."
    fi
else
    echo "[i] Docker is unavailable; no n8n container was stopped."
fi

echo "[+] Stopping Ollama..."
ollama_stopped=false

if [[ "$(uname -s)" == "Darwin" ]]; then
    if command -v osascript &> /dev/null && osascript -e 'tell application "Ollama" to quit' >/dev/null 2>&1; then
        ollama_stopped=true
    fi
elif [[ "$(uname -s)" == "Linux" ]] && command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet ollama; then
        if sudo systemctl stop ollama; then
            ollama_stopped=true
        else
            echo "[!] Could not stop the Ollama system service."
            stop_failed=true
        fi
    elif systemctl --user is-active --quiet ollama; then
        if systemctl --user stop ollama; then
            ollama_stopped=true
        else
            echo "[!] Could not stop the Ollama user service."
            stop_failed=true
        fi
    fi
fi

# The start script can launch `ollama serve` directly instead of through a service.
if command -v pgrep &> /dev/null && pgrep -x ollama >/dev/null 2>&1; then
    if command -v pkill &> /dev/null && pkill -TERM -x ollama; then
        ollama_stopped=true
    elif [[ "$ollama_stopped" != true ]]; then
        echo "[!] Could not stop the Ollama process."
        stop_failed=true
    fi
fi

if [[ "$ollama_stopped" == true ]]; then
    echo "[✓] Ollama stopped."
elif ! command -v pgrep &> /dev/null || ! pgrep -x ollama >/dev/null 2>&1; then
    echo "[i] Ollama was already stopped."
fi

if [[ "$stop_failed" == true ]]; then
    exit 1
fi
