{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Vendor CLIs pinned by hash, bumped by `update-ai-clis`. Its sed matches one
# line per tool, so do NOT run nixfmt on this file — it splits them and the
# bump silently stops working.
let
  pins = {
    claude-code = { version = "2.1.224"; hash = "sha256-PlCDbiJ4aHRic2U+D4EVz1/JyzSggYR8YEDIHYCBLDM="; };
    codex = { version = "0.147.0"; hash = "sha256-62d8gPZmsauLSx0IO2bo1hSxKB2WC7b5/Yypj1izi5A="; };
    grok = { version = "1.0.0"; hash = "sha256-u3xREWVkoiGfakmFCBUGD0FpGKxAfx8rqCxTwLDUOD8="; };
    kimi = { version = "0.34.0"; hash = "sha256-25yI0PREIPEkXPdF6ttWneGOzYMBnsq4iLMCjt3zboc="; };
    opencode = { version = "1.18.15"; hash = "sha256-UAYRgZ/4iRaxhWSZkFBam+dq0Tylu0uTI+Wr3Tmxxvs="; };
    cursor-agent = { version = "2026.08.04-aaa8809"; hash = "sha256-1RliiSkqZgtZgHrFCMmsNuweGhp+RpevPvaCT96phO4="; };
  };

  meta = homepage: desc: {
    inherit homepage;
    description = desc;
    platforms = [ "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
{
  # Do NOT autoPatchelf: Bun appends its payload after the ELF, and patching
  # shifts it out of reach, silently degrading to the plain Bun runtime.
  claude-code = stdenvNoCC.mkDerivation {
    pname = "claude-code";
    inherit (pins.claude-code) version;
    src = fetchurl {
      url = "https://downloads.claude.ai/claude-code-releases/${pins.claude-code.version}/linux-arm64/claude";
      inherit (pins.claude-code) hash;
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/claude"
      runHook postInstall
    '';
    meta = meta "https://code.claude.com" "Anthropic's Claude Code CLI" // { mainProgram = "claude"; };
  };

  codex = stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit (pins.codex) version;
    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${pins.codex.version}/codex-aarch64-unknown-linux-musl.tar.gz";
      inherit (pins.codex) hash;
    };
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 "$(find . -type f -name 'codex*' -perm -u+x | head -1)" "$out/bin/codex"
      cat <<'EOF' > $out/bin/codex-code-mode-host
#!/bin/sh
dir="$(dirname "$0")"
if [ "$#" -eq 0 ]; then
  exec "$dir/codex" mcp-server "$@"
else
  exec "$dir/codex" "$@"
fi
EOF
      chmod +x $out/bin/codex-code-mode-host
      runHook postInstall
    '';
    meta = meta "https://github.com/openai/codex" "OpenAI's Codex CLI" // { mainProgram = "codex"; };
  };

  grok = stdenvNoCC.mkDerivation {
    pname = "grok";
    inherit (pins.grok) version;
    src = fetchurl {
      url = "https://x.ai/cli/grok-${pins.grok.version}-linux-aarch64";
      inherit (pins.grok) hash;
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/grok"
      runHook postInstall
    '';
    meta = meta "https://x.ai/cli" "x.ai's official Grok CLI" // { mainProgram = "grok"; };
  };

  # Kimi Code, the rebuilt successor to the Python kimi-cli. Its own installer
  # renames the first `kimi` on PATH to `kimi-legacy` and deletes later
  # duplicates, which would maul the store path — pin it here instead and never
  # run `/upgrade`. Versions come from code.kimi.com, not GitHub, which is still
  # publishing the old 1.x line.
  kimi = stdenvNoCC.mkDerivation {
    pname = "kimi";
    inherit (pins.kimi) version;
    src = fetchurl {
      url = "https://code.kimi.com/kimi-code/binaries/${pins.kimi.version}/kimi-code-linux-arm64";
      inherit (pins.kimi) hash;
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/kimi"
      runHook postInstall
    '';
    meta = meta "https://code.kimi.com" "Moonshot's Kimi Code CLI" // { mainProgram = "kimi"; };
  };

  # Bun-compiled like claude-code, so the same no-autoPatchelf rule applies.
  opencode = stdenvNoCC.mkDerivation {
    pname = "opencode";
    inherit (pins.opencode) version;
    src = fetchurl {
      url = "https://github.com/sst/opencode/releases/download/v${pins.opencode.version}/opencode-linux-arm64.tar.gz";
      inherit (pins.opencode) hash;
    };
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 opencode "$out/bin/opencode"
      runHook postInstall
    '';
    meta = meta "https://github.com/sst/opencode" "SST's OpenCode terminal agent" // { mainProgram = "opencode"; };
  };

  # Ships its own node next to the launcher, so the tree moves whole and only
  # the launcher gets linked into bin.
  cursor-agent = stdenvNoCC.mkDerivation {
    pname = "cursor-agent";
    inherit (pins.cursor-agent) version;
    src = fetchurl {
      url = "https://downloads.cursor.com/lab/${pins.cursor-agent.version}/linux/arm64/agent-cli-package.tar.gz";
      inherit (pins.cursor-agent) hash;
    };
    sourceRoot = "dist-package";
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec" "$out/bin"
      cp -r . "$out/libexec/cursor-agent"
      ln -s "$out/libexec/cursor-agent/cursor-agent" "$out/bin/cursor-agent"
      runHook postInstall
    '';
    meta = meta "https://cursor.com/cli" "Cursor's agent CLI" // { mainProgram = "cursor-agent"; };
  };

}
