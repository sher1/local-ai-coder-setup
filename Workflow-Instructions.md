# Setting Up an n8n Multi-Model Specialist Workflow

This guide details how to configure an autonomous, multi-agent orchestration workflow in **n8n** using local [Ollama](https://ollama.com) models based on the system architecture.

---

## Workflow Overview

The n8n workflow operates as a multi-stage pipeline designed for efficiency, speed, and strict verification:

1. **Trigger** -> Captures incoming user prompt/task.
2. **Router Node** -> Classifies intent and generates a JSON execution plan.
3. **Switch Node** -> Directs execution to the specialized worker model.
4. **Specialist Worker** -> Produces code, analysis, or guidance. Current workers do not have tools, file access, or command execution.
5. **Verifier Node** -> Evaluates worker output against original success criteria.
6. **Feedback Loop** -> Loops back on failure (max 2 retries) or outputs final result.

---

## 1. Initial Setup & Connection

1. Open your browser and navigate to `http://localhost:5678`.
2. Create a new blank **Workflow**.
3. Add a **Webhook** node or a **Manual Trigger** node as the entry point to capture incoming user requests.
4. When connecting n8n (running in Docker) to Ollama, point your base URL to:
   `http://host.docker.internal:11434`

---

## 2. Router Node (Task Classification)

The Router analyzes user intent and generates a structured execution plan without attempting to solve the task itself.

* **Model:** `qwen3.5:2b`
* **Temperature:** `0.0`
* **Node Type:** **HTTP Request** node (`/api/generate`) or the official **Ollama** node.
* **System Prompt:**
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
  Derive concise criteria from the user request. Do not invent execution, testing, file-writing, installation, server, or deployment requirements unless the user explicitly asks. For simple code generation, criteria should focus on providing the requested code and necessary usage notes.
  Do not solve the problem. Return raw JSON only.
  ```

---

## 3. Router Switch / IF Node

Add an n8n **Switch** or **If** node directly after the Router to parse the JSON output (`target_worker` field) and route execution down the appropriate path:

* **Branch 1 (`coder`):** Routes to the **Coding Specialist**.
* **Branch 2 (`researcher` / `general`):** Routes to the **General Worker / Research Specialist**.

---

## 4. Specialist Worker Nodes

### A. Coding Specialist Path
* **Model:** `qwen2.5-coder:7b-instruct`
* **Temperature:** `0.1`
* **Role:** Produces code, patches, and coding guidance from the task details provided. In the current workflow it cannot inspect or modify files or execute commands/tests.
* Keep the response proportional to the request. For a simple script request, provide a complete minimal script first; omit installation, hosting, and deployment guidance unless requested. Never claim files were changed or commands/tests were run.

### B. Research / General Worker Path
* **Model:** `qwen3.5:4b`
* **Temperature:** `0.2`
* **Role:** Handles web research, SQL/Python generation, or general queries.
* **n8n Integration:** Use n8n **HTTP Request** nodes to fetch external web content or query API endpoints safely without direct file system access.

---

## 5. Verifier Node (Quality Check)

Once the worker node completes its output, pass both the **original success criteria** (from the Router) and the **worker's output** into the Verifier node.

* **Model:** `qwen3.5:4b`
* **Temperature:** `0.0`
* **Node Type:** **Ollama** or **HTTP Request** node.
* **System Prompt:**
  ```text
  Evaluate the output against the original user request and reasonable success criteria. Workers have no tools and cannot execute code. For code-generation requests, judge whether requested code is present and logically correct; do not fail it merely because it was not run unless the user explicitly requested execution/testing and the workflow actually performed it. Do not enforce invented setup, hosting, installation, or deployment requirements. Fail only for a missing deliverable, clear correctness/safety issue, or unmet explicit requirement.
  Return raw JSON only:
  {
    "passed": true | false,
    "feedback": "Reason for failure if passed is false"
  }
  ```

---

## 6. Feedback Loop & Retry Logic

Add an **If** node after the Verifier to check if `passed == true`:

* **Path A (`passed == true`):** Send the worker's output to the final response node to complete the workflow.
* **Path B (`passed == false`):** Send the code and failure details to the Deep Debugger, then pass its concise diagnosis to the Coding Specialist for correction. Route non-coding failures back to the relevant General Worker / Research Specialist node.

> **Note:** Configure a Loop Counter node in n8n to cap retries at a **maximum of 2 iterations** to prevent infinite loop cycles.

### Deep Debugger Node

Use this node for failed coding attempts before retrying with the Coding Specialist.

* **Model:** `deepseek-r1:7b`
* **Temperature:** `0.6`
* **System Prompt:**
  ```text
  Identify the likely root cause of the failure from the code and error logs. Return a concise explanation and actionable instructions for the coding model. Provide conclusions and supporting evidence, not hidden chain-of-thought.
  ```
