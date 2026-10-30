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
      - N8N_LOG_OUTPUT=console,file
      - N8N_LOG_FILE_LOCATION=/logs/n8n.log
      - N8N_LOG_FILE_SIZE_MAX=16
      - N8N_LOG_FILE_COUNT_MAX=10
      - N8N_RESTRICT_FILE_ACCESS_TO=/logs
    volumes:
      - n8n_data:/home/node/.n8n
      - ./.n8n:/logs
      - ./workflows/workflow.json:/tmp/workflow.json:ro

volumes:
  n8n_data:
```

The workflow definition is tracked at `workflows/workflow.json` and mounted read-only at `/tmp/workflow.json` inside the container. The start script imports it once. n8n writes logs to `.n8n/n8n.log` on the host, with up to 10 rotated 16 MB files. Workflow model interactions are appended as JSONL records to `.n8n/workflow-interactions.jsonl`; each record includes the execution ID, step, model, task context, model response, token counts, and Ollama timing metrics in milliseconds, plus elapsed time measured around each model request. Final results also report the log path and aggregate timing per model. These logs can contain task prompts and model responses. Local `.n8n` data is ignored by Git.

### `start_local_team.sh`

The unified script supports macOS and Linux. It installs Ollama if needed, checks or starts its server, pulls the configured models, starts n8n, and imports the workflow on first setup.

---

## 📖 How to Use the System

### 1. Access the Dashboards
* **Ollama API Endpoint:** `http://localhost:11434`
* **n8n Orchestrator UI:** `http://localhost:5678`

### 2. Submit a Task

1. Start the setup with `./start_local_team.sh` and open the n8n UI at `http://localhost:5678`. If this is your first visit, complete n8n's owner-account setup.
2. Open **Local Multi-Model Specialist Pipeline** and select the **Task Prompt** form trigger.
3. Click **Execute step** on the form trigger to start its test listener.
4. Open the test form at [http://localhost:5678/form-test/local-ai-task](http://localhost:5678/form-test/local-ai-task), enter a task, and select **Run task**. For example: `Create a PHP Hello World script`.
5. Leave the form page open while the local models work. When the workflow finishes, the page displays the result, verification status, feedback, token counts, and per-model timings. Completed runs that need review also show a result page.

The test listener accepts one submission at a time. To submit another task, click **Execute step** on **Task Prompt** again and reload the test form. The production form URL (`http://localhost:5678/form/local-ai-task`) is available after activating the workflow in n8n.

Detailed model interactions are saved locally in `.n8n/workflow-interactions.jsonl`; n8n execution details are available from the **Executions** view in the UI.

### 3. Workflow Configuration

The included workflow is imported by `start_local_team.sh`; there is no need to create a second workflow in n8n. For the detailed node setup, routing logic, worker roles, prompts, verification, and retry behavior, use [Workflow-Instructions.md](Workflow-Instructions.md) as the single reference.

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
