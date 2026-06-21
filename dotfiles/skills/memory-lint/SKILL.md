---
name: "Memory Graph Auditor"
description: "Audit the local AI memory system (Obsidian vault) for formatting compliance, broken links, journal parent references, and note staleness."
---

# Memory Graph Auditor Skill

This skill allows the agent to audit your local AI memory system (Obsidian vault) located at `/Users/uynx/ai_memory/`.

## When to Trigger
- Trigger this skill at the beginning or end of a session, or when requested, to check the health of the memory vault.
- Can be run automatically to find broken links, formatting issues, or notes that have gone stale.

## How to Execute
Run the Python auditor script directly:
```bash
python3 /Users/uynx/.gemini/config/skills/memory-lint/scripts/lint_memory.py
```
