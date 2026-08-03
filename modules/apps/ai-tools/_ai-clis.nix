{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Vendor-distributed AI CLIs, pinned by hash and bumped by `update-ai-clis`.
#
# WHY NOT nixpkgs: not staleness — measured 2026-07-26, nixpkgs-unstable had
# codex at exactly upstream and claude-code two patches behind. The problem is
# coupling: taking today's release from nixpkgs means a whole `nix flake
# update`, dragging every other package forward to bump one CLI. Pinning here
# decouples the two. (`grok` additionally has no nixpkgs package at all —
# nixpkgs' `grok-cli` is superagent-ai's unrelated tool of the same name.)
#
# To add another AI CLI, copy one of these three. Between them they cover every
# shape a vendor ships: a bare static binary, a bare dynamic binary needing
# autoPatchelf, and a tarball. Then add a matching `bump` line to
# `update-ai-clis` in default.nix — the pins below are rewritten by sed, so
# keep this one-line-per-tool layout exactly as it is.
let
  pins = {
    codex = { version = "0.146.0"; hash = "sha256-l1uskVYqvu3rj3ljbVGoZkmzHzSp3mo7ywWVZbbPH4c="; };
    grok = { version = "0.2.118"; hash = "sha256-VAEOM1qs5rXe3QIlOeznvIPzglPoY2qvB5ZWKu7LLmc="; };
  };

  meta = homepage: desc: {
    inherit homepage;
    description = desc;
    platforms = [ "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
{
  # Tarball containing a single statically-linked musl binary.
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

  # Bare binary, statically linked — nothing to unpack or patch.
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
}
