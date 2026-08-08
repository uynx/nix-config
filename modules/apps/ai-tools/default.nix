{
  # Everything about the AI CLIs that is the same on both platforms: the shared
  # skills/AGENTS.md wiring, and `update-ai-clis` — the one entry point that
  # maintains every tool. How the tools themselves arrive differs per platform:
  # linux.nix pins them, darwin.nix brews them.
  flake.homeModules.aiTools =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      home = config.home.homeDirectory;
      inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

      skillsDir = "${home}/dotfiles/skills";
      sharedSkills =
        if builtins.pathExists skillsDir then
          builtins.attrNames (
            lib.filterAttrs (n: t: t == "directory" && !lib.hasPrefix "." n) (builtins.readDir skillsDir)
          )
        else
          [ ];

      update-ai-clis = pkgs.writeShellApplication {
        name = "update-ai-clis";
        runtimeInputs =
          with pkgs;
          [
            curl
            nix
            gnused
            jq
            nodejs
            uv
            git # hermes' installer clones its own repo

            # t3 pulls node-pty, which has no linux-arm64 prebuild and compiles on
            # install. Without these npm dies on `c++: not found`.
            python3
            gnumake
          ]
          # macOS builds these against the Xcode toolchain instead; a nix gcc in
          # PATH there makes node-gyp pick the wrong compiler entirely.
          ++ lib.optionals isLinux [
            gcc
            binutils
          ];
        text = ''
          # Home Manager activation calls this with --missing-only to make a
          # fresh machine self-populate. $HOME is /homeless-shelter there, so
          # every path below is the literal home instead.
          missingOnly=
          if [ "''${1:-}" = --missing-only ]; then
            missingOnly=1
          fi
          export PATH="$PATH:${home}/.local/bin:${home}/.hermes/bin"

          ${lib.optionalString isLinux ''
            file=${home}/nixos-config/modules/apps/ai-tools/pins.json

            # bump <name> <latest-version> <download-url>
            bump() {
              name=$1 latest=$2 url=$3

              # Refuse to invent a key: `.[$n] = …` would happily create one, so a
              # typo'd name would add a pin nothing reads instead of failing.
              current=$(jq -r --arg n "$name" '.[$n].version // ""' "$file")
              if [ -z "$current" ]; then
                echo "$name: no such pin in $file" >&2
                return 1
              fi
              if [ "$current" = "$latest" ]; then
                printf '%-12s %s (up to date)\n' "$name" "$current"
                return
              fi

              hash=$(nix hash convert --hash-algo sha256 --to sri \
                "$(nix-prefetch-url --type sha256 "$url")")

              tmp=$(mktemp)
              jq --arg n "$name" --arg v "$latest" --arg h "$hash" \
                '.[$n] = { version: $v, hash: $h }' "$file" >"$tmp"
              mv "$tmp" "$file"

              printf '%-12s %s -> %s\n' "$name" "$current" "$latest"
            }

            if [ -z "$missingOnly" ]; then
            claude=$(curl -fsSL https://downloads.claude.ai/claude-code-releases/latest | tr -d '[:space:]')
            bump claude-code "$claude" \
              "https://downloads.claude.ai/claude-code-releases/$claude/linux-arm64/claude"

            # npm, not the GitHub feed — the GitHub tarball omits the code-mode
            # host binary, so the feed has to match the source we actually fetch.
            codex=$(curl -fsSL https://registry.npmjs.org/@openai/codex/latest | jq -r '.version')
            bump codex "$codex" \
              "https://registry.npmjs.org/@openai/codex/-/codex-$codex-linux-arm64.tgz"

            grok=$(curl -fsSL https://x.ai/cli/stable | tr -d '[:space:]')
            bump grok "$grok" "https://x.ai/cli/grok-$grok-linux-aarch64"

            kimi=$(curl -fsSL https://code.kimi.com/kimi-code/latest | tr -d '[:space:]')
            bump kimi "$kimi" \
              "https://code.kimi.com/kimi-code/binaries/$kimi/kimi-code-linux-arm64"

            opencode=$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest \
              | jq -r '.tag_name | ltrimstr("v")')
            bump opencode "$opencode" \
              "https://github.com/sst/opencode/releases/download/v$opencode/opencode-linux-arm64.tar.gz"

            cursor=$(curl -fsSL https://cursor.com/install | sed -n 's|.*downloads\.cursor\.com/lab/\([^/]*\)/.*|\1|p' | head -1)
            bump cursor-agent "$cursor" \
              "https://downloads.cursor.com/lab/$cursor/linux/arm64/agent-cli-package.tar.gz"

            echo
            echo 'rolling (takes effect now, no rebuild):'
            fi
          ''}

          get_ver() {
            bin=$1
            case "$bin" in
              agy) agy --version 2>/dev/null | head -1 ;;
              openclaw) openclaw --version 2>/dev/null | head -1 | sed 's/OpenClaw //' ;;
              t3) t3 --version 2>/dev/null | head -1 | sed 's/t3 //' ;;
              qwen) (qwen --version 2>/dev/null || qwen-code --version 2>/dev/null) | head -1 ;;
              hermes) hermes --version 2>/dev/null | head -1 | sed 's/Hermes Agent //' ;;
              kimi) kimi --version 2>/dev/null | head -1 ;;
              *) echo "" ;;
            esac
          }

          # Keep stderr: a swallowed failure here reads exactly like success,
          # which is how this once installed nothing at all.
          roll() {
            name=$1
            shift
            if [ -n "$missingOnly" ] && command -v "$name" >/dev/null 2>&1; then
              return
            fi
            before=$(get_ver "$name")
            if err=$("$@" 2>&1); then
              after=$(get_ver "$name")
              if [ -n "$before" ] && [ -n "$after" ] && [ "$before" = "$after" ]; then
                printf '  %-12s %s (up to date)\n' "$name" "$after"
              elif [ -n "$before" ] && [ -n "$after" ]; then
                printf '  %-12s %s -> %s\n' "$name" "$before" "$after"
              elif [ -n "$after" ]; then
                printf '  %-12s %s\n' "$name" "$after"
              else
                printf '  %-12s ok\n' "$name"
              fi
            else
              printf '  %-12s FAILED\n' "$name"
              printf '%s\n' "$err" | tail -3 | sed 's/^/               /'
            fi
          }

          roll agy      agy update
          roll openclaw npm install -g --prefix "${home}/.local" openclaw
          roll t3       npm install -g --prefix "${home}/.local" t3
          roll qwen     npm install -g --prefix "${home}/.local" @qwen-code/qwen-code
          ${lib.optionalString isDarwin ''
            # The only tool with neither a darwin pin nor a Homebrew formula, so
            # it is fetched straight from the vendor. Version is read at install
            # time rather than recorded, which is what makes it rolling.
            # shellcheck disable=SC2016  # $v is for the inner sh, not this one
            roll kimi sh -c '
              v=$(curl -fsSL https://code.kimi.com/kimi-code/latest | tr -d "[:space:]")
              mkdir -p ${home}/.local/bin
              curl -fsSL -o ${home}/.local/bin/kimi \
                "https://code.kimi.com/kimi-code/binaries/$v/kimi-code-darwin-arm64"
              chmod +x ${home}/.local/bin/kimi'
          ''}
          # Vendor installer, not `uv tool install`: upstream marks every pypi
          # install unsupported. It brings its own node and uv under ~/.hermes,
          # so it costs minutes and is only worth running when hermes is absent.
          # Afterwards `hermes update` maintains itself, and `--check` settles it
          # in about a second. --check always exits 0, hence the string match; if
          # upstream reworded it we would merely go back to updating every run.
          if ! command -v hermes >/dev/null 2>&1; then
            roll hermes sh -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
              | bash -s -- --non-interactive --hermes-home ${home}/.hermes'
          elif [ -z "$missingOnly" ]; then
            ver=$(get_ver hermes)
            if hermes update --check 2>&1 | grep -q 'Already up to date'; then
              printf '  %-12s %s (up to date)\n' hermes "$ver"
            else
              roll hermes hermes update --yes
            fi
          fi
        '';
      };
    in
    {
      home.packages = [ update-ai-clis ];

      home.sessionVariables = {
        # Without these a self-updater fetches a newer build into ~/.local and
        # the pin stops being what actually runs.
        DISABLE_AUTOUPDATER = "1";
        GROK_DISABLE_AUTOUPDATER = "1";
        OPENCODE_DISABLE_AUTOUPDATE = "1";
        AGY_CLI_DISABLE_AUTO_UPDATE = "1";

        # Appended, not home.sessionPath: that prepends, letting a self-installed
        # binary here silently outrank its pinned version.
        PATH = "$PATH:${home}/.local/bin";
      }
      # hermes' browser tool otherwise makes Playwright fetch its own Ubuntu
      # Chromium, which will not run unpatched here. Reuses whatever browser the
      # host already builds rather than adding 3.2 GB of pkgs.chromium — so it
      # only applies on a host that took the `web` bundle.
      // lib.optionalAttrs config.programs.chromium.enable {
        AGENT_BROWSER_EXECUTABLE_PATH = "${config.programs.chromium.package}/bin/brave-origin";
      };

      # One set of skills and one AGENTS.md, wired to wherever each CLI expects
      # to find them. Deliberately outside the store: the memory workflow
      # rewrites both constantly and a read-only store symlink would break it.
      #
      # Cursor is the one tool that gets skills but not instructions: its user
      # rules are .mdc files with frontmatter, which a plain AGENTS.md is not.
      home.file =
        lib.genAttrs
          [
            ".agents/AGENTS.md"
            ".claude/CLAUDE.md"
            ".codex/AGENTS.md"
            ".cursorrules"
            ".cursor/rules/system.mdc"
            ".grok/AGENTS.md"
            ".kimi-code/AGENTS.md"
            ".openclaw/AGENTS.md"
            ".qwen/QWEN.md"
            ".config/opencode/AGENTS.md"
          ]
          (_: {
            source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
          })
        //
          lib.genAttrs
            [
              ".agents/skills"
              ".claude/skills"
              ".cursor/skills"
              ".grok/skills"
              ".kimi-code/skills"
              ".openclaw/skills"
              ".qwen/skills"
              ".config/opencode/skills"
            ]
            (_: {
              source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
            })
        # codex is the exception: ~/.codex/skills already holds its own vendor
        # skills under .system, and a directory symlink would displace them. So
        # each skill is linked individually alongside them. Read impurely
        # because the source is a working copy, not a flake input; a machine
        # without the dotfiles clone simply gets none.
        // lib.listToAttrs (
          map (skill: {
            name = ".codex/skills/${skill}";
            value.source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills/${skill}";
          }) sharedSkills
        );

      home.activation.createRequiredDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p \
          "${home}/ai_memory/topics" \
          "${home}/ai_memory/journal" \
          "${home}/dotfiles" \
          "${home}/nixos-config"
      '';

      # hermes finds extra skills through a config key rather than a path, and
      # writes that config itself, so it cannot be a store symlink. Appending is
      # safe only while it has no `skills:` block of its own; if it grows one,
      # the key has to be merged in by hand instead.
      home.activation.hermesSharedSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="${home}/.hermes/config.yaml"
        if [ -f "$cfg" ] && ! grep -qE '^skills:|external_dirs' "$cfg"; then
          printf '\nskills:\n  external_dirs:\n    - %s\n' "${home}/.agents/skills" >>"$cfg"
        fi
      '';

      # agy, openclaw, t3 and hermes cannot be pinned or brewed, so a fresh
      # machine would otherwise have most but not all of the CLIs. This installs
      # only what is absent, making every later rebuild a no-op, and never fails
      # the activation — an offline rebuild must still succeed.
      home.activation.installRollingAiClis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${update-ai-clis}/bin/update-ai-clis --missing-only || true
      '';
    };
}
