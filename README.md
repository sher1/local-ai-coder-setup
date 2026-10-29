## This is based on the article [here](https://www.xda-developers.com/replaced-claude-code-tiny-specialists-boring-setup-worked-better/)
# Local Multi-Model AI Specialist Team

An autonomous, multi-agent LLM orchestration system powered by [Ollama](https://ollama.com/) and [n8n](https://n8n.io/).

Instead of relying on a single expensive frontier model to handle every task, this architecture divides work across a team of lightweight, specialized local models running entirely on your machine.

---

## 🏗️ How It Works (System Architecture)

When you submit a prompt or request, it flows through a multi-stage pipeline designed for efficiency and verification. Tasks are routed by type to a general worker, a coding specialist, or the debugger. The debugger analyzes failures before sending feedback to the coding model for a retry.

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
      ┌───────────────────────────┼───────────────────────────┐
      ▼                           ▼                           ▼
┌───────────────┐           ┌───────────────┐           ┌───────────────┐
│ Coding Node   │           │ Research Node │           │ General Node  │
│ Qwen 2.5 Coder│           │ Qwen 3.5 4B   │           │ Qwen 3.5 4B   │
│      7B       │           │               │           │               │
└───────┬───────┘           └───────┬───────┘           └───────┬───────┘
        │                           │                           │
        └───────────────────────────┴───────────────┬───────────┘
                                                    │
                                                    ▼
                                      ┌──────────────────────────┐
                                      │  Verifier (Qwen 3.5 4B)  │  <-- Evaluates output vs success criteria
                                      └─────────────┬────────────┘
                                                    │
                                      ┌─────────────┴─────────────┐
                                      │                           │
                              [ Failed Check ]             [ Passed Check ]
                              (Attempt #1 Fail)                   │
                                      │                           ▼
                                      ▼                    [ Final Output ]
                            ┌──────────────────┐
                            │  Deep Debugger   │  <-- Analyzes difficult failures
                            │ (DeepSeek R1 7B) │
                            └─────────┬────────┘
                                      │
                                      └──────► Retries Coding Node with reasoning feedback
```

### Specialist Breakdown

| Role | Model | Temperature | VRAM / System RAM | Responsibility |
| :--- | :--- | :--- | :--- | :--- |
| **Router** | `qwen3.5:2b` | `0.0` | ~2.7–3.1 GB model download | Classifies tasks, target languages, and target files, returning a strict JSON execution plan. |
| **Coding Specialist** | `qwen2.5-coder:7b-instruct` | `0.1` | ~4.7 GB model download | Handles code generation, code reasoning, and code fixes across the project's languages. |
| **General Worker and Verifier** | `qwen3.5:4b` | `0.0–0.2` | ~3.3–4.0 GB model download | Handles general/research tasks and checks outputs against success criteria. |
| **Deep Debugger** | `deepseek-r1:7b` | `0.6` | Varies by quantization and context | Analyzes difficult failures and gives actionable feedback to the coding model. |

---

## 💻 Hardware Requirements & Performance

* **RAM:** 32 GB (System RAM is heavily utilized for model layer splitting).
* **GPU VRAM:** 4 GB+ (AMD RX 6500 XT or equivalent).
* **CPU:** 6 cores / 12 threads (e.g., AMD Ryzen 5 5600X).
* **Disk Space:** ~17 GB free space for the model weights, plus room for runtime and context memory.
* **Performance:** The 7B coder and debugger exceed 4 GB of VRAM, so expect CPU/system RAM use and slower inference. Actual GPU offload depends on operating system and Ollama backend support.

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
   * Use the included `start_local_team.sh` script.

3. **Run the setup script:**
   ```bash
   ./start_local_team.sh
   ```

This script will automatically:
* Install Ollama (if missing).
* Configure Ollama for one loaded model and one parallel request, with Flash Attention enabled.
* Pull the four models used by the team: Qwen3.5 2B, Qwen2.5-Coder 7B, Qwen3.5 4B, and DeepSeek R1 7B.
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
      - ./.n8n:/files:ro
      - ./workflows/workflow.json:/tmp/workflow.json:ro

volumes:
  n8n_data:
```

The workflow definition is tracked at `workflows/workflow.json` and mounted read-only at `/tmp/workflow.json` inside the container. The start script imports it once; local `.n8n` data is ignored by Git.

### `start_local_team.sh`

The unified script supports macOS and Linux. It installs Ollama if needed, checks or starts its server, pulls the configured models, starts n8n, and imports the workflow on first setup.

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
  "language": "python" | "node" | "go" | "php" | "other",
  "target_worker": "coder" | "researcher" | "general",
  "files": [],
  "success_criteria": "string"
}
Route coding tasks in any language, including Go and PHP, to "coder".
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

#### Deep Debugger Node System Prompt (`deepseek-r1:7b`)
```text
Analyze the failing code and execution error logs provided.
Identify the likely root cause of the failure from the code and error logs. Return a concise explanation and actionable instructions for the coding model. Provide conclusions and supporting evidence, not hidden chain-of-thought.
```

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
