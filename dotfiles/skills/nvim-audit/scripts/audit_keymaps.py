import os
import re
import sys

NVIM_DIR = "/Users/uynx/nix-config/dotfiles/nvim"
MASTERY_FILE = "/Users/uynx/ai_memory/concepts/neovim_mastery.md"

def extract_keymaps():
    keymaps = []
    
    # 1. Walk through the lua configuration
    for root, dirs, files in os.walk(NVIM_DIR):
        for file in files:
            if file.endswith(".lua"):
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, NVIM_DIR)
                
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
                
                # Check for standard lazy.nvim style keys tables: { "<key>", "<action>" ... } in plugin specs
                if "lua/plugins/" in rel_path:
                    lazy_keys = re.findall(r'\{\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\'](?:,\s*desc\s*=\s*["\']([^"\']+)["\'])?\s*\}', content)
                    for key, action, desc in lazy_keys:
                        description = desc if desc else action
                        keymaps.append((key, description, rel_path))
                
                # Check for vim.keymap.set(mode, lhs, rhs, opts)
                set_keys = re.findall(r'vim\.keymap\.set\(\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']', content)
                for mode, lhs, rhs in set_keys:
                    keymaps.append((lhs, f"[{mode}] {rhs}", rel_path))
                
                # Check for specific plugin options keymaps like copilot
                copilot_keys = re.findall(r'(next|prev|dismiss)\s*=\s*["\']([^"\']+)["\']', content)
                if copilot_keys and "copilot" in content:
                    for action, key in copilot_keys:
                        keymaps.append((key, f"Copilot {action} suggestion", rel_path))

    return keymaps

def update_mastery_file(keymaps):
    if not os.path.exists(MASTERY_FILE):
        print(f"Error: {MASTERY_FILE} does not exist.")
        return

    with open(MASTERY_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # Generate Markdown Table
    table_lines = [
        "| Key | Action / Description | Defined In |",
        "| :--- | :--- | :--- |"
    ]
    
    # Remove duplicates and sort
    seen = set()
    unique_keymaps = []
    for key, desc, src in keymaps:
        if (key, desc) not in seen:
            seen.add((key, desc))
            unique_keymaps.append((key, desc, src))
            
    unique_keymaps.sort(key=lambda x: x[0])
    
    for key, desc, src in unique_keymaps:
        clean_key = f"`{key}`"
        clean_desc = f"`{desc}`" if desc.startswith("<") or desc.startswith("vim") or desc.startswith("[") else desc
        table_lines.append(f"| {clean_key} | {clean_desc} | [{os.path.basename(src)}](file:///Users/uynx/nix-config/dotfiles/nvim/{src}) |")

    table_content = "\n".join(table_lines)

    # Wrap in section
    new_section = (
        f'    <section id="custom-keybindings">\n'
        f'## Custom Keybindings\n'
        f'This table is automatically generated from your Neovim configurations:\n\n'
        f'{table_content}\n'
        f'    </section>\n'
    )

    if "</article>" not in content:
        print("Error: Closing </article> tag not found in mastery file.")
        return

    # Check if section id="custom-keybindings" already exists
    if 'id="custom-keybindings"' in content:
        pattern = r'    <section id="custom-keybindings">.*?</section>\n'
        updated_content = re.sub(pattern, new_section, content, flags=re.DOTALL)
    else:
        updated_content = content.replace("</article>", f"{new_section}</article>")

    with open(MASTERY_FILE, "w", encoding="utf-8") as f:
        f.write(updated_content)

    print(f"Successfully audited keymaps and updated {MASTERY_FILE}")

def main():
    keymaps = extract_keymaps()
    if not keymaps:
        print("No custom keymaps found.")
        sys.exit(0)
    update_mastery_file(keymaps)

if __name__ == "__main__":
    main()
