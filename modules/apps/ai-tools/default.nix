{
  flake.homeModules.aiTools =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      home = config.home.homeDirectory;
      inherit (pkgs.stdenv.hostPlatform) isLinux;

      skillsDir = "${home}/dotfiles/skills";
      sharedSkills =
        if builtins.pathExists skillsDir then
          builtins.attrNames (
            lib.filterAttrs (n: t: t == "directory" && builtins.pathExists "${skillsDir}/${n}/SKILL.md") (
              builtins.readDir skillsDir
            )
          )
        else
          [ ];

      update-ai-clis = pkgs.writeShellApplication {
        name = "update-ai-clis";
        runtimeInputs =
          with pkgs;
          [
            coreutils
            util-linux
          ]
          ++ lib.optionals isLinux [
            curl
            nix
            gnused
            jq
            nodejs
          ];
        text = ''
          missingOnly=
          if [ "''${1:-}" = --missing-only ]; then
            missingOnly=1
          fi

          exec 9>"/tmp/update-ai-clis.$(id -u).lock"
          if ! flock -n 9; then
            echo "update-ai-clis: another run is already installing, skipping" >&2
            exit 0
          fi
          export PATH="$PATH:${home}/.local/bin"
          ${lib.optionalString isLinux "export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"}

          export CI=1

          skipped=0
          sk=$(mktemp)

          ${lib.optionalString isLinux ''
            file=${home}/nix-config/modules/apps/ai-tools/pins.json

            bump() {
              name=$1 latest=$2 url_arm=$3 url_x86=$4

              if [ -z "$latest" ] || [ "$latest" = null ]; then
                printf '%-12s SKIPPED (lookup failed)\n' "$name"
                return 1
              fi

              current=$(jq -r --arg n "$name" '.[$n].version // ""' "$file")
              if [ -z "$current" ]; then
                echo "$name: no such pin in $file" >&2
                return 1
              fi
              if [ "$current" = "$latest" ]; then
                printf '%-12s %s (up to date)\n' "$name" "$current"
                return 0
              fi

              prefetch() {
                nix hash convert --hash-algo sha256 --to sri \
                  "$(nix-prefetch-url --type sha256 "$1")"
              }

              if ! hash_arm=$(prefetch "$url_arm") || ! hash_x86=$(prefetch "$url_x86"); then
                printf '%-12s SKIPPED (prefetch failed)\n' "$name"
                return 1
              fi

              tmp=$(mktemp)
              jq --arg n "$name" --arg v "$latest" --arg a "$hash_arm" --arg x "$hash_x86" \
                '.[$n] = { version: $v, hash: { "aarch64-linux": $a, "x86_64-linux": $x } }' \
                "$file" >"$tmp"
              mv "$tmp" "$file"

              printf '%-12s %s -> %s\n' "$name" "$current" "$latest"
            }

            try_bump() {
              bump "$@" || skipped=$((skipped + 1))
            }

            if [ -z "$missingOnly" ]; then
            claude=$(curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 https://downloads.claude.ai/claude-code-releases/latest | tr -d '[:space:]' || true)
            try_bump claude-code "$claude" \
              "https://downloads.claude.ai/claude-code-releases/$claude/linux-arm64/claude" \
              "https://downloads.claude.ai/claude-code-releases/$claude/linux-x64/claude"

            codex=$(curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 https://registry.npmjs.org/@openai/codex/latest | jq -r '.version' || true)
            try_bump codex "$codex" \
              "https://registry.npmjs.org/@openai/codex/-/codex-$codex-linux-arm64.tgz" \
              "https://registry.npmjs.org/@openai/codex/-/codex-$codex-linux-x64.tgz"

            grok=$(curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 https://x.ai/cli/stable | tr -d '[:space:]' || true)
            try_bump grok "$grok" "https://x.ai/cli/grok-$grok-linux-aarch64" \
              "https://x.ai/cli/grok-$grok-linux-x86_64"

            echo
            echo 'rolling (takes effect now, no rebuild):'
            fi
          ''}

          get_ver() {
            bin=$1
            case "$bin" in
              agy) agy --version 2>/dev/null | head -1 ;;
              t3) t3 --version 2>/dev/null | head -1 | sed 's/t3 //' ;;
              *) echo "" ;;
            esac
          }

          spin() {
            name=$1
            pid=$2
            out=$3
            [ -t 1 ] || return 0
            chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            i=0
            last=""
            start=$(date +%s)
            while kill -0 "$pid" 2>/dev/null; do
              c=''${chars:i++%10:1}
              elapsed=$(( $(date +%s) - start ))
              if [ "$elapsed" -ge 60 ]; then
                t="$((elapsed / 60))m $((elapsed % 60))s"
              else
                t="''${elapsed}s"
              fi
              if [ $((i % 10)) -eq 1 ]; then
                last=$(tr '\r' '\n' <"$out" 2>/dev/null \
                  | sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' -e '/^[[:space:]]*$/d' \
                  | tail -1 || true)
              fi
              printf '  %-12s %s %-8s %.40s\r' \
                "$name" "$c" "$t" "$last"
              sleep 0.1
            done
            printf '\r\033[K'
          }

          roll() {
            name=$1
            shift
            if [ -n "$missingOnly" ] && command -v "$name" >/dev/null 2>&1; then
              return
            fi
            before=$(get_ver "$name" || true)
            tmp=$(mktemp)
            "$@" >"$tmp" 2>&1 &
            pid=$!
            spin "$name" "$pid" "$tmp"
            if wait "$pid"; then
              after=$(get_ver "$name" || true)
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
              tail -3 "$tmp" | sed 's/^/               /'
              echo >>"$sk"
            fi
            rm -f "$tmp"
          }

          ${lib.optionalString isLinux ''
            if command -v agy >/dev/null 2>&1; then
              roll agy    agy update
            else
              roll agy    sh -c 'curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 https://antigravity.google/cli/install.sh | bash'
            fi &
          ''}
          ${lib.optionalString (!isLinux) ''
            if [ -f /opt/homebrew/bin/agy ] && [ ! -L /opt/homebrew/bin/agy ]; then
              rm -f /opt/homebrew/bin/agy
            fi
          ''}
          ${lib.optionalString isLinux ''
            roll t3 npm install -g --prefix "${home}/.local" t3 &
          ''}
          wait
          skipped=$((skipped + $(wc -l <"$sk")))
          rm -f "$sk"
          if [ "$skipped" -gt 0 ]; then
            echo
            echo "$skipped not updated this run — rerun to retry."
          fi
        '';
      };
    in
    {
      home = {
        packages = [ update-ai-clis ];

        sessionVariables = {
          DISABLE_AUTOUPDATER = "1";
          CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
          GROK_DISABLE_AUTOUPDATER = "1";
          AGY_CLI_DISABLE_AUTO_UPDATE = "1";

          PATH = "$PATH:${home}/.local/bin";
        }
        // lib.optionalAttrs config.programs.chromium.enable {
          AGENT_BROWSER_EXECUTABLE_PATH = "${config.programs.chromium.package}/bin/brave-origin";
        };

        file =
          lib.genAttrs
            [
              ".agents/AGENTS.md"
              ".claude/CLAUDE.md"
              ".codex/AGENTS.md"
              ".gemini/AGENTS.md"
              ".grok/AGENTS.md"
            ]
            (_: {
              source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
            })
          //
            lib.genAttrs
              [
                ".agents/skills"
                ".claude/skills"
                  ".gemini/skills"
                ".grok/skills"
                      ]
              (_: {
                source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
              })
          // lib.listToAttrs (
            map (skill: {
              name = ".codex/skills/${skill}";
              value.source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills/${skill}";
            }) sharedSkills
          )
          // lib.optionalAttrs isLinux {
            ".local/share/applications/t3.desktop".text = ''
              [Desktop Entry]
              Type=Application
              Name=T3 Code
              GenericName=AI coding workspace
              Exec=${home}/.local/bin/t3
              Terminal=false
              Categories=Development;
            '';
          };

        activation = {
          claudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            ln -sfn ${home}/dotfiles/claude-settings.json ${home}/.claude/settings.json
          '';

          installRollingAiClis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${update-ai-clis}/bin/update-ai-clis --missing-only || true
          '';
        };
      };

      shellHooks.update = [ "update-ai-clis" ];
    };
}
