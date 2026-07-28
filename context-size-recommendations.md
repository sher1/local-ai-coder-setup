# Recommended Model Context Windows (`num_ctx`)

To set custom context windows (`num_ctx`) for each model in your local setup, you have **two main approaches** depending on whether you want to configure it at the **n8n / API request level** or hardcode it into **Ollama Modelfiles**.

---

## Option 1: Configure via n8n / API Requests (Recommended)

When making HTTP requests or using the Ollama node in n8n, pass `options.num_ctx` inside the JSON payload for each specific call.

### Example Payload for Coding Specialist (`16384` tokens):
```json
{
  "model": "qwen3.5:9b",
  "prompt": "Refactor the following function...",
  "options": {
    "num_ctx": 16384,
    "temperature": 0.1
  }
}
```

### Example Payload for Router Node (`2048` tokens):
```json
{
  "model": "qwen3.5:2b",
  "prompt": "Classify this request...",
  "format": "json",
  "options": {
    "num_ctx": 2048,
    "temperature": 0.0
  }
}
```

---

## Option 2: Hardcode Context Windows via Ollama Modelfiles

If you want a model to *always* default to a specific context size whenever loaded locally, create a custom model variant using a `Modelfile`.

### 1. Create a `Modelfile`:
```dockerfile
FROM qwen3.5:9b
PARAMETER num_ctx 16384
```

### 2. Create the custom model variant:
```bash
ollama create qwen3.5-16k -f Modelfile
```

Referencing `qwen3.5-16k` in your scripts or n8n nodes will automatically load it with a 16K token context window.

---

## Recommended Context Sizes for Your Setup

Given your **32 GB RAM** and **4 GB VRAM**, here are optimal `num_ctx` values to balance memory usage and window capacity:

* **Router (`qwen3.5:2b`):** `2048` (Keeps VRAM usage low and response time under 1 second).
* **Verifier (`qwen3.5:4b`):** `4096` or `8192` (Sufficient to evaluate raw execution logs against requirements).
* **General Worker (`qwen3.5:9b`):** `8192`
* **Coder / Go & PHP / Debugger (`qwen3.5:9b`, `deepseek-coder-v2:16b`, `deepseek-r1:7b`):** `16384` (Ensures full code files, multi-file contexts, and deep stack traces fit into context without truncation).
