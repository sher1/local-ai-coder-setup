## This is based on the article [here](https://www.xda-developers.com/replaced-claude-code-tiny-specialists-boring-setup-worked-better/) 
# Local Multi-Model AI Specialist Team

An autonomous, multi-agent LLM orchestration system powered by [Ollama](https://ollama.com/) and [n8n](https://n8n.io/). 

Instead of relying on a single expensive frontier model to handle every task, this architecture divides work across a team of lightweight, specialized local models running entirely on your machine.

---

## 🏗️ How It Works (System Architecture)

When you submit a prompt or request, it flows through a multi-stage pipeline designed for efficiency, speed, and strict verification:

```
                  ┌────────────────┐
                  │  User Request  │
                  └───────┬────────┘
                          │
                          ▼
            ┌──────────────────────────┐
            │   Router (Qwen 3.5 2B)   │  <-- Analyzes intent, outputs JSON plan
            └─────────────┬────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
┌────────────────┐ ┌─────────────┐ ┌──────────────┐
│  Coding Node   │ │ Research    │ │ General      │  <-- Executes task with 
│ (Qwen 3.5 9B)  │ │(Qwen 3.5 9B)│ │ (Qwen 3.5 9B)│      restricted tools
└───────┬────────┘ └──────┬──────┘ └──────┬───────┘
        │                 │               │
        └─────────────────┼───────────────┘
                          │
                          ▼
            ┌──────────────────────────┐
            │  Verifier (Qwen 3.5 4B)  │  <-- Evaluates output vs success criteria
            └─────────────┬────────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
    [ Failed Check ]             [ Passed Check ]
  (Max 2 retries back                 │
   to specialized worker)             ▼
                               [ Final Output ]
```

### Specialist Breakdown

| Role | Model | Temperature | VRAM / System RAM | Responsibility |
| :--- | :--- | :--- | :--- | :--- |
| **Router** | `qwen3.5:2b` | `0.0` | ~1.5 GB | Classifies tasks, extracts target files, and returns a strict JSON execution plan. Does **not** solve the problem itself. |
| **Coder Specialist** | `qwen3.5:9b` | `0.1` | ~6.0 GB Total | Inspects codebases, modifies local files, and runs terminal tests in a sandboxed directory. |
| **Worker Specialist** | `qwen3.5:9b` | `0.2` | ~6.0 GB Total | Handles web research, data processing (Python/SQL generation), and automated tasks via approved n8n nodes. |
| **Verifier** | `qwen3.5:4b` | `0.0` | ~3.0 GB | Compares the worker’s output against the original success criteria. If tests fail, it loops back to the worker with raw error logs (up to 2 retries). |

---

## 💻 Hardware Requirements & Performance

* **RAM:** 32 GB (System RAM is heavily utilized for model layer splitting).
* **GPU VRAM:** 4 GB+ (AMD RX 6500 XT or equivalent).
* **CPU:** 6 cores / 12 threads (e.g., AMD Ryzen 5 5600X).
* **Disk Space:** ~25 GB free space for Qwen 3.5 model weights.

---

## 🚀 Installation & Setup

### Prerequisites

Ensure you have the following installed on your system:
1. **Git**
2. **Docker & Docker Compose**

### Step-by-Step Setup

1. **Clone or create your project directory:**
   ```bash
   mkdir local-ai-team && cd local-ai-team
   ```

2. **Save the project files:**
   * Create `docker-compose.yml` (see below).
   * Create `setup_local_team.sh` and make it executable:
     ```bash
     chmod +x setup_local_team.sh
     ```

3. **Run the setup script:**
   ```bash
   ./setup_local_team.sh
   ```

This script will automatically:
* Install Ollama (if missing).
* Configure environment variables for CPU/RAM optimization (`OLLAMA_MAX_LOADED_MODELS=2`).
* Pull all required Qwen 3.5 model weights into your local library.
* Launch the **n8n** visual workflow manager inside a Docker container via Docker Compose.

---

## 📁 Configuration Files

### `docker-compose.yml`
```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n_specialists
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
```

### `setup_local_team.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "================================================="
echo "   Setting up Local Multi-Model AI Specialist Team"
echo "================================================="

# 1. Check for Ollama
if ! command -v ollama &> /dev/null; then
    echo "[+] Installing Ollama..."
    curl -fsSL [https://ollama.com/install.sh](https://ollama.com/install.sh) | sh
else
    echo "[✓] Ollama is installed."
fi

# 2. Configure Ollama Environment for CPU/RAM optimization
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_NUM_PARALLEL=1

echo "[+] Pulling specialist models into local library..."
echo "--> Router (Qwen 3.5 2B)..."
ollama pull qwen3.5:2b

echo "--> Coding Specialist (Qwen 3.5 9B)..."
ollama pull qwen3.5:9b

echo "--> General Worker (Qwen 3.5 9B)..."
ollama pull qwen3.5:9b

echo "--> Verifier (Qwen 3.5 4B)..."
ollama pull qwen3.5:4b

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
```

---

## 📖 How to Use the System

### 1. Access the Dashboards
* **Ollama API Endpoint:** `http://localhost:11434`
* **n8n Orchestrator UI:** `http://localhost:5678`

### 2. Setting Up the Orchestrator (n8n)

1. Open `http://localhost:5678` in your browser and complete the one-time account creation.
2. Create a new Workflow.
3. Add **HTTP Request Nodes** or official **Ollama Nodes** configured to connect to `http://host.docker.internal:11434` (or `http://localhost:11434`).
4. Configure node prompts according to their roles:

#### Router Node System Prompt (`qwen3.5:2b`)
```text
You are a strict task classifier. Analyze the user request and output ONLY a JSON object:
{
  "task_type": "coding" | "research" | "data",
  "target_worker": "coder" | "researcher" | "general",
  "files": [],
  "success_criteria": "string"
}
Do not solve the problem. Return raw JSON only.
```

#### Verifier Node System Prompt (`qwen3.5:4b`)
```text
Evaluate whether the output provided by the worker meets the target success_criteria.
Return raw JSON only:
{
  "passed": true | false,
  "feedback": "Reason for failure if passed is false"
}
```

### 3. Example Workflows

* **Fixing Code:** Send a request like *"Fix the failing unit tests in `src/utils.py`"*. 
  * The Router flags `target_worker: "coder"` and sets `success_criteria: "pytest passes"`.
  * The Coding Specialist (`qwen3.5:9b`) edits the file and executes tests via local command nodes.
  * The Verifier checks test logs. If successful, execution stops; if failed, it feeds the output back into the coder.

* **Research Task:** Send a request like *"Find the latest security advisories for Drupal 10"*.
  * The Router sends the job to `researcher`.
  * The worker uses n8n HTTP nodes to pull web content without file system access.
  * The Verifier confirms that every claim includes an attached web URL source.

---

## 🛠️ Management Commands

* **View running containers:**
  ```bash
  docker compose ps
  ```
* **View n8n execution logs:**
  ```bash
  docker compose logs -f n8n
  ```
* **Stop the setup:**
  ```bash
  docker compose down
  ```
* **List loaded local LLMs:**
  ```bash
  ollama list
  ```
