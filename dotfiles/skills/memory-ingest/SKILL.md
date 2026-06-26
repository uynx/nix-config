---
name: "Vault Ingest"
description: "Process new raw document sources (articles, papers, notes) added to the vault, synthesize their contents, update relevant concept nodes, maintain indices, and log the action."
---

# Vault Ingest Skill

Use this skill when you need to process new raw documents (Markdown clips, PDFs, text files) located in `/Users/uynx/ai_memory/raw/` or provided directly by the user.

## When to Trigger
- Trigger this skill when the user drops new files in `raw/` and asks to ingest them, or when they ask you to "ingest this article/paper".

## Ingestion Workflow Steps

### Step 1: Read the Source
- Locate and read the target file inside `/Users/uynx/ai_memory/raw/`.
- Extract the core concepts, data points, safety guidelines, or instructions.

### Step 2: Synthesis and Planning
- Identify which existing concepts in `concepts/` are affected by this new information.
- Plan what edits need to be made to maintain accuracy (e.g. updating supplement stack dosings, rehab progressions, or Nix packages).
- If a completely new concept is introduced, plan to create a new concept node at `concepts/{concept_name}.md` following the vault's HTML-wrapper protocol.

### Step 3: Propose Edits to the User
- Present the planned changes to the user clearly (e.g. showing a markdown diff or describing the additions).
- Ask for the user's explicit permission to perform the file modifications (in accordance with the rule: *NEVER edit files directly without proposing first*).

### Step 4: Perform Updates (Upon Approval)
- Update/Create the target concept files inside `concepts/`.
- Ensure all updated files preserve the hybrid HTML/Markdown format (wrapping headers, H2 headings in sections, etc.).

### Step 5: Update the Central Index and Active Projects
- Add a reference link to the new concepts or sources in `/Users/uynx/ai_memory/index.md` under the appropriate section.
- If the ingestion relates to an active project milestone, update `/Users/uynx/ai_memory/projects.md`.

### Step 6: Log the Transaction
- Append a daily log note at `/Users/uynx/ai_memory/journal/{project}_{date}.md` detailing the ingestion, what data points changed, and linking the new file.
- Ensure the log contains proper parent backlinks at the bottom.

### Step 7: Clean Up/Archive the Source File
- Upon successful ingestion and logging, move the original raw source file from `/Users/uynx/ai_memory/raw/` to the archive directory `/Users/uynx/ai_memory/raw/archive/` to keep your incoming raw folder clean.

### Step 8: Sync Memory Vault
- Using caveman lite level to write the commit message, run the `memory-sync` utility to commit and push changes.
