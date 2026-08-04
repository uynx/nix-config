{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Vendor CLIs pinned by hash, bumped by `update-ai-clis`. One line per tool:
# the pins are rewritten by sed, so keep that layout.
let
  pins = {
    claude-code = { version = "2.1.221"; hash = "sha256-08Wda8xK3PTNhavKO8E/oRMaNMsy+YK98DDYOjsR5wA="; };
    codex = { version = "0.146.0"; hash = "sha256-l1uskVYqvu3rj3ljbVGoZkmzHzSp3mo7ywWVZbbPH4c="; };
    grok = { version = "0.2.118"; hash = "sha256-VAEOM1qs5rXe3QIlOeznvIPzglPoY2qvB5ZWKu7LLmc="; };
    kimi = { version = "1.49.0"; hash = "sha256-WsVMq84W7eJ7nSBpubiO3uJVKGRue7W++pmAocpx/rs="; };
    opencode = { version = "1.18.12"; hash = "sha256-grnFFXt64QrLX+rO2wfJCpttzpTvs7cGDIY7BzpiKtA="; };
    cursor-agent = { version = "2026.07.23-e383d2b"; hash = "sha256-9AuZZHyyTg2ohel2IKIEgDTx/olhkQ1XPYJ9d8TSbcs="; };
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

  kimi = stdenvNoCC.mkDerivation {
    pname = "kimi";
    inherit (pins.kimi) version;
    src = fetchurl {
      url = "https://github.com/MoonshotAI/kimi-cli/releases/download/${pins.kimi.version}/kimi-${pins.kimi.version}-aarch64-unknown-linux-gnu.tar.gz";
      inherit (pins.kimi) hash;
    };
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 kimi "$out/bin/kimi"
      runHook postInstall
    '';
    meta = meta "https://github.com/MoonshotAI/kimi-cli" "Moonshot's Kimi CLI" // { mainProgram = "kimi"; };
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
