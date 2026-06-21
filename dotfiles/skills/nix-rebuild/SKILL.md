---
name: "Nix-Darwin Config Rebuild"
description: "Automatically verify, commit, and push Mac Nix-Darwin system configuration changes, and instruct the user to rebuild."
---

# Nix-Darwin Config Rebuild Skill

Use this skill when nix-darwin or home-manager configuration files under `/Users/uynx/nix-config/` have been modified and need to be built and activated.

## When to Trigger
- Trigger this skill automatically after modifying `.nix` configuration files in the workspace.
- Can be manually invoked by saying "rebuild nix config" or similar.

## Action Steps
1. **Verify Syntax**: Run `nix flake check` to verify configuration syntax:
   ```bash
   nix flake check --no-build /Users/uynx/nix-config
   ```
2. **Auto-Commit and Push**: If the syntax check passes, stage the changes, generate a concise, human-sounding commit message based on the modified files (mimicking past commits such as "Updates.", "Cleanup", "Add AI memory tracking", or "Configure <feature>"), commit, and push directly to GitHub:
   ```bash
   git add .
   git commit -m "<human_message>"
   git push
   ```
3. **Instruct Rebuild**: Clearly output the changes made, confirm that they have been committed and pushed to GitHub, and instruct the user to run the rebuild alias in their interactive terminal:
   ```bash
   reb
   ```
4. **Troubleshoot Failures**: If the user reports that `reb` failed:
   - Parse the compiler output or error logs.
   - Propose and implement a fix.
   - Run `nix flake check` again, auto-commit/push the fix, and prompt the user to run `reb` again.
