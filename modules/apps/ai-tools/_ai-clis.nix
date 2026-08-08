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

  # `url` is a function of the version so the pin is read once, here, rather
  # than named twice per package. Default to a vendor that ships one bare
  # executable; an archive names its `sourceRoot` and its own `install`.
  mkPin =
    {
      pname,
      url,
      homepage,
      desc,
      bin ? pname,
      sourceRoot ? null,
      install ? ''install -Dm755 "$src" "$out/bin/${bin}"'',
    }:
    stdenvNoCC.mkDerivation (
      {
        inherit pname;
        inherit (pins.${pname}) version;
        src = fetchurl {
          url = url pins.${pname}.version;
          inherit (pins.${pname}) hash;
        };
        installPhase = ''
          runHook preInstall
          ${lib.removeSuffix "\n" install}
          runHook postInstall
        '';
        meta = meta homepage desc // {
          mainProgram = bin;
        };
      }
      // (if sourceRoot == null then { dontUnpack = true; } else { inherit sourceRoot; })
    );
in
{
  # Do NOT autoPatchelf: Bun appends its payload after the ELF, and patching
  # shifts it out of reach, silently degrading to the plain Bun runtime. Same
  # for opencode below, which is built the same way.
  claude-code = mkPin {
    pname = "claude-code";
    bin = "claude";
    url = v: "https://downloads.claude.ai/claude-code-releases/${v}/linux-arm64/claude";
    homepage = "https://code.claude.com";
    desc = "Anthropic's Claude Code CLI";
  };

  # Source is npm, not the GitHub release: that tarball ships `codex` alone,
  # while every GPT-5.6 model is `tool_mode = code_mode_only` and routes all
  # tool calls through a sibling `codex-code-mode-host` binary that only the
  # npm platform package carries. Without it every call dies at "timed out
  # negotiating with the code-mode host". The `codex` binaries are identical.
  codex = mkPin {
    pname = "codex";
    url = v: "https://registry.npmjs.org/@openai/codex/-/codex-${v}-linux-arm64.tgz";
    sourceRoot = "package/vendor/aarch64-unknown-linux-musl";
    install = ''install -Dm755 bin/codex bin/codex-code-mode-host -t "$out/bin"'';
    homepage = "https://github.com/openai/codex";
    desc = "OpenAI's Codex CLI";
  };

  grok = mkPin {
    pname = "grok";
    url = v: "https://x.ai/cli/grok-${v}-linux-aarch64";
    homepage = "https://x.ai/cli";
    desc = "x.ai's official Grok CLI";
  };

  # Kimi Code, the rebuilt successor to the Python kimi-cli. Its own installer
  # renames the first `kimi` on PATH to `kimi-legacy` and deletes later
  # duplicates, which would maul the store path — pin it here instead and never
  # run `/upgrade`. Versions come from code.kimi.com, not GitHub, which is still
  # publishing the old 1.x line.
  kimi = mkPin {
    pname = "kimi";
    url = v: "https://code.kimi.com/kimi-code/binaries/${v}/kimi-code-linux-arm64";
    homepage = "https://code.kimi.com";
    desc = "Moonshot's Kimi Code CLI";
  };

  opencode = mkPin {
    pname = "opencode";
    url = v: "https://github.com/sst/opencode/releases/download/v${v}/opencode-linux-arm64.tar.gz";
    sourceRoot = ".";
    install = ''install -Dm755 opencode "$out/bin/opencode"'';
    homepage = "https://github.com/sst/opencode";
    desc = "SST's OpenCode terminal agent";
  };

  # Ships its own node next to the launcher, so the tree moves whole and only
  # the launcher gets linked into bin.
  cursor-agent = mkPin {
    pname = "cursor-agent";
    url = v: "https://downloads.cursor.com/lab/${v}/linux/arm64/agent-cli-package.tar.gz";
    sourceRoot = "dist-package";
    install = ''
      mkdir -p "$out/libexec" "$out/bin"
      cp -r . "$out/libexec/cursor-agent"
      ln -s "$out/libexec/cursor-agent/cursor-agent" "$out/bin/cursor-agent"
    '';
    homepage = "https://cursor.com/cli";
    desc = "Cursor's agent CLI";
  };
}
