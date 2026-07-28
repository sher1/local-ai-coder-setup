# Hardware & Workflow Optimization Notes

Additional optimizations and tools tailored for an AMD RX 6500 XT (4GB VRAM), Ryzen 5 5600X, 32GB RAM local AI setup running Python, Node.js, Go, and PHP.

---

## 1. Dynamic VRAM / RAM Offloading Tweaks

* **Enable Flash Attention:** Reduces VRAM overhead during long-context operations (e.g., passing large error logs to the Verifier or Debugger):
  ```bash
  export OLLAMA_FLASH_ATTENTION=1
  ```
* **Explicit Context Windows (`num_ctx`):** Force larger context limits in n8n/Ollama API calls for Coder and Debugger nodes (`num_ctx: 8192` or `16384`) to prevent stack trace truncation.

---

## 2. Local Codebase Context Tools

* **Repomix (`files-to-prompt`):** Packs an entire codebase or subdirectory into a single LLM-friendly XML file (respecting `.gitignore`). Ideal for pre-processing files in n8n before passing to coding nodes:
  ```bash
  npx repomix --style xml
  ```
* **Local Vector DB (RAG):** For large codebases (e.g., Drupal CMS modules or complex Go microservices), consider running **Qdrant** or **ChromaDB** via Docker Compose to enable semantic search over codebase contexts instead of loading raw files.

---

## 3. Ollama API Parameters for Structured Output

For Router and Verifier nodes that must output strict JSON schema:
* Set `"format": "json"` in the API request body.
* Set `"temperature": 0.0` to eliminate response variability.
* Include explicit JSON output templates directly inside the system prompts.
