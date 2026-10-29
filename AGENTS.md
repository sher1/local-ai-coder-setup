# AGENTS.md — Project Rules & Self‑Check Prompt

## Documentation
- Write all project documentation in Markdown (`.md`) format.

## System Constraints
- CPU is AMD Ryzen 5600x
- System RAM is 32GB
- Graphics card is Radeon 6500XT 4GB of VRAM

## Project Context
- **Stack:** TypeScript, React 18, Tailwind CSS; Go applications following the standard-library `net/http` patterns and project structure used in `~/dev/otis-admin`; PHP applications following Drupal development standards
- **Linting:** ESLint + Prettier for TypeScript; `gofmt` and `go vet` for Go; Drupal Coding Standards with PHP_CodeSniffer/Drupal Coder for PHP
- **Testing:** Jest + React Testing Library for TypeScript; `go test` for Go; PHPUnit and Drupal's Kernel/Functional tests as appropriate for PHP
- **CI:** GitHub Actions workflows in `.github/workflows/`

## Core Rules
1. Always follow TypeScript strict mode.
2. Use functional components with hooks; avoid class components unless required.
3. Document all public APIs in JSDoc comments.

## Cupcake Self‑Check Prompt
Before finalizing any code or explanation:
1. **State assumptions** — list any assumptions you made about the task.
2. **Check completeness** — confirm all required inputs/outputs are addressed.
3. **Verify logic** — walk through the solution step‑by‑step to ensure no gaps.
4. **Flag uncertainty** — if unsure, ask clarifying questions instead of guessing.
5. **Only output final code** after passing the above checks.

If any step fails, revise your reasoning and repeat until all checks pass.

## Enforcement
- Apply these rules in all code generation tasks.
- For ambiguous requests, prioritize clarity and correctness over speed.