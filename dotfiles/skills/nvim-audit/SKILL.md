---
name: "Neovim Keybinding Auditor"
description: "Audit Neovim configuration files for custom keybindings and generate an up-to-date cheat sheet table in your memory vault."
---

# Neovim Keybinding Auditor Skill

This skill allows the agent to automatically scan your Neovim configurations at `/Users/uynx/nix-config/dotfiles/nvim` and update your learning reference node at `/Users/uynx/ai_memory/concepts/neovim_mastery.md` with a clean, dynamic custom keybindings reference table.

## When to Trigger
- Trigger this skill when Neovim keymaps or plugins are modified.
- Can be manually invoked by saying "audit nvim keymaps" or "run nvim keymap audit".

## How to Execute
Run the Python keymap auditor script:
```bash
python3 /Users/uynx/.gemini/config/skills/nvim-audit/scripts/audit_keymaps.py
```
