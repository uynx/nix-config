{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Vendor CLIs pinned by hash. `update-ai-clis` rewrites pins.json with jq, so
# this file is ordinary Nix and safe to format.
let
  pins = builtins.fromJSON (builtins.readFile ./pins.json);

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
    meta = meta "https://code.claude.com" "Anthropic's Claude Code CLI" // {
      mainProgram = "claude";
    };
  };

  # Source is npm, not the GitHub release: that tarball ships `codex` alone,
  # while every GPT-5.6 model is `tool_mode = code_mode_only` and routes all
  # tool calls through a sibling `codex-code-mode-host` binary that only the
  # npm platform package carries. Without it every call dies at "timed out
  # negotiating with the code-mode host". The `codex` binaries are identical.
  codex = stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit (pins.codex) version;
    src = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${pins.codex.version}-linux-arm64.tgz";
      inherit (pins.codex) hash;
    };
    sourceRoot = "package/vendor/aarch64-unknown-linux-musl";
    installPhase = ''
      runHook preInstall
      install -Dm755 bin/codex bin/codex-code-mode-host -t "$out/bin"
      runHook postInstall
    '';
    meta = meta "https://github.com/openai/codex" "OpenAI's Codex CLI" // {
      mainProgram = "codex";
    };
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
    meta = meta "https://x.ai/cli" "x.ai's official Grok CLI" // {
      mainProgram = "grok";
    };
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
    meta = meta "https://code.kimi.com" "Moonshot's Kimi Code CLI" // {
      mainProgram = "kimi";
    };
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
    meta = meta "https://github.com/sst/opencode" "SST's OpenCode terminal agent" // {
      mainProgram = "opencode";
    };
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
    meta = meta "https://cursor.com/cli" "Cursor's agent CLI" // {
      mainProgram = "cursor-agent";
    };
  };

}
