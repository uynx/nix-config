{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  pins = builtins.fromJSON (builtins.readFile ./pins.json);

  inherit (stdenvNoCC.hostPlatform) system;
  cpu = stdenvNoCC.hostPlatform.parsed.cpu.name;
  short = if cpu == "aarch64" then "arm64" else "x64";

  meta = homepage: desc: {
    inherit homepage;
    description = desc;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

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
          hash = pins.${pname}.hash.${system};
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
  claude-code = mkPin {
    pname = "claude-code";
    bin = "claude";
    url = v: "https://downloads.claude.ai/claude-code-releases/${v}/linux-${short}/claude";
    homepage = "https://code.claude.com";
    desc = "Anthropic's Claude Code CLI";
  };

  codex = mkPin {
    pname = "codex";
    url = v: "https://registry.npmjs.org/@openai/codex/-/codex-${v}-linux-${short}.tgz";
    sourceRoot = "package/vendor/${cpu}-unknown-linux-musl";
    install = ''install -Dm755 bin/codex bin/codex-code-mode-host -t "$out/bin"'';
    homepage = "https://github.com/openai/codex";
    desc = "OpenAI's Codex CLI";
  };

  grok = mkPin {
    pname = "grok";
    url = v: "https://x.ai/cli/grok-${v}-linux-${cpu}";
    homepage = "https://x.ai/cli";
    desc = "x.ai's official Grok CLI";
  };

  kimi = mkPin {
    pname = "kimi";
    url = v: "https://code.kimi.com/kimi-code/binaries/${v}/kimi-code-linux-${short}";
    homepage = "https://code.kimi.com";
    desc = "Moonshot's Kimi Code CLI";
  };

  opencode = mkPin {
    pname = "opencode";
    url = v: "https://github.com/sst/opencode/releases/download/v${v}/opencode-linux-${short}.tar.gz";
    sourceRoot = ".";
    install = ''install -Dm755 opencode "$out/bin/opencode"'';
    homepage = "https://github.com/sst/opencode";
    desc = "SST's OpenCode terminal agent";
  };

  cursor-agent = mkPin {
    pname = "cursor-agent";
    url = v: "https://downloads.cursor.com/lab/${v}/linux/${short}/agent-cli-package.tar.gz";
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
