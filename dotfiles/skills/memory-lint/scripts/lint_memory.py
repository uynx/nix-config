import os
import re
import sys
import time

VAULT_DIR = "/Users/uynx/ai_memory"
STALE_DAYS = 14

def audit_vault():
    if not os.path.isdir(VAULT_DIR):
        print(f"Error: Vault directory {VAULT_DIR} does not exist.")
        sys.exit(1)

    # 1. Build index of valid note names (lowercase)
    note_paths = {}
    for root, dirs, files in os.walk(VAULT_DIR):
        if ".obsidian" in root or "raw" in root:
            continue
        for file in files:
            if file.endswith(".md"):
                name = os.path.splitext(file)[0].lower()
                rel_path = os.path.relpath(os.path.join(root, file), VAULT_DIR)
                note_paths[name] = rel_path

    errors = []
    warnings = []
    stale_notes = []

    # Read index.md to check for unindexed notes
    index_path = os.path.join(VAULT_DIR, "index.md")
    indexed_notes = set()
    if os.path.exists(index_path):
        with open(index_path, "r", encoding="utf-8") as f:
            index_content = f.read()
        # Find all wikilinks in index.md
        index_links = re.findall(r'\[\[([^\]]+)\]\]', index_content)
        for link in index_links:
            target = link.split("|")[0].strip().lower()
            indexed_notes.add(target)
    else:
        errors.append("index.md: Central vault index file is missing.")

    # 2. Audit each file
    for name, rel_path in note_paths.items():
        filepath = os.path.join(VAULT_DIR, rel_path)
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        lines = content.splitlines()
        
        # Check if indexed in index.md
        if rel_path not in ["index.md", "identity.md", "projects.md"] and name not in indexed_notes:
            warnings.append(f"{rel_path}: Note is not indexed in index.md")

        # Check staleness
        mtime = os.path.getmtime(filepath)
        days_since_mod = (time.time() - mtime) / (24 * 3600)
        
        # Check staleness for concepts or identity/projects
        if rel_path.startswith("concepts/") or rel_path in ["identity.md", "projects.md"]:
            if days_since_mod > STALE_DAYS:
                stale_notes.append((rel_path, int(days_since_mod)))

        # A. Check article tags wrapper
        if not lines:
            errors.append(f"{rel_path}: File is empty.")
            continue

        if not lines[0].strip().startswith("<article>"):
            errors.append(f"{rel_path}: File does not start with '<article>' (found: '{lines[0]}')")

        article_end_idx = -1
        for idx, line in enumerate(lines):
            if line.strip() == "</article>" or line.strip().startswith("</article>"):
                article_end_idx = idx
                break

        if article_end_idx == -1:
            errors.append(f"{rel_path}: Closing '</article>' tag not found.")

        # B. Check header and H2 section wrapping
        header_found = False
        section_stack = []
        
        for idx, line in enumerate(lines[:article_end_idx+1]):
            if "<header>" in line:
                header_found = True
            
            section_match = re.search(r'<section\s+id="([^"]+)">', line)
            if section_match:
                section_stack.append((idx + 1, section_match.group(1)))
            
            if "</section>" in line:
                if section_stack:
                    section_stack.pop()
                else:
                    errors.append(f"{rel_path}:L{idx+1}: Unmatched closing '</section>' tag.")

            if line.strip().startswith("## ") and not line.strip().startswith("###"):
                if not section_stack:
                    errors.append(f"{rel_path}:L{idx+1}: Heading '{line.strip()}' is not wrapped in a '<section id=\"...\">' block.")

        for start_line, sec_id in section_stack:
            errors.append(f"{rel_path}:L{start_line}: Section '{sec_id}' is not closed before </article>.")

        if not header_found and not rel_path.endswith("README.md"):
            warnings.append(f"{rel_path}: No '<header>' tag found.")

        # C. Parse and validate wikilinks [[link]] (ignoring code blocks/backticks)
        clean_content = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
        clean_content = re.sub(r'`[^`\n]+`', '', clean_content)
        links = re.findall(r'\[\[([^\]]+)\]\]', clean_content)
        for link in links:
            target = link.split("|")[0].strip().lower()
            if target not in note_paths:
                errors.append(f"{rel_path}: Broken link to [[{link}]]")

        # D. Validate footer links are outside </article>
        if article_end_idx != -1:
            footer_content = "\n".join(lines[article_end_idx+1:])
            if rel_path.startswith("journal/"):
                # Validate Parent
                if "**Parent**:" not in footer_content:
                    errors.append(f"{rel_path}: Journal entry missing '**Parent**: [[project_name]]' in footer.")
                else:
                    parent_match = re.search(r'\*\*Parent\*\*:\s*\[\[([^\]]+)\]\]', footer_content)
                    if parent_match:
                        p_target = parent_match.group(1).strip().lower()
                        if p_target not in note_paths:
                            errors.append(f"{rel_path}: Broken parent link in footer: [[{parent_match.group(1)}]]")
                    else:
                        errors.append(f"{rel_path}: Invalid Parent link format in footer.")

                # Validate Prev
                if "**Prev**:" not in footer_content:
                    errors.append(f"{rel_path}: Journal entry missing '**Prev**' field in footer.")
                else:
                    prev_match = re.search(r'\*\*Prev\*\*:\s*(\[\[([^\]]+)\]\]|None \(Initial Node\))', footer_content)
                    if prev_match:
                        if "[[" in prev_match.group(1):
                            prev_target = prev_match.group(2).strip().lower()
                            if prev_target not in note_paths:
                                errors.append(f"{rel_path}: Broken prev link in footer: [[{prev_match.group(2)}]]")
                    else:
                        errors.append(f"{rel_path}: Invalid Prev link format in footer (must be 'None (Initial Node)' or '[[prev_log]]').")

                # Validate Overlap
                overlap_matches = re.findall(r'\*\*Overlap\*\*:\s*\[\[([^\]]+)\]\]', footer_content)
                for overlap_target in overlap_matches:
                    o_target = overlap_target.strip().lower()
                    if o_target not in note_paths:
                        errors.append(f"{rel_path}: Broken overlap link in footer: [[{overlap_target}]]")

                # Validate coding log quality
                parent_match = re.search(r'\*\*Parent\*\*:\s*\[\[([^\]]+)\]\]', footer_content)
                if parent_match:
                    parent_name = parent_match.group(1).strip().lower()
                    if parent_name in ["local_ai_memory_system", "nix_darwin_setup", "neovim_mastery"]:
                        if not any("<section id=\"accomplishments\">" in line for line in lines):
                            warnings.append(f"{rel_path}: Coding log is missing a '<section id=\"accomplishments\">' block.")
                        if "file:///" not in content:
                            warnings.append(f"{rel_path}: Coding log contains no clickable file:/// links (document changes using file:/// links).")

    # 3. Print report
    print("# Obsidian AI Memory Audit Report")
    print(f"Scan complete. Checked {len(note_paths)} notes.")
    
    if errors:
        print("\n## ❌ Errors")
        for err in errors:
            print(f"- {err}")
    else:
        print("\n## ✅ Errors\n- No errors found.")

    if warnings:
        print("\n## ⚠️ Warnings")
        for warn in warnings:
            print(f"- {warn}")

    if stale_notes:
        print(f"\n## 🕒 Stale Notes (No edits in > {STALE_DAYS} days)")
        for note, days in sorted(stale_notes, key=lambda x: x[1], reverse=True):
            print(f"- {note} (last edited {days} days ago)")

if __name__ == "__main__":
    audit_vault()
