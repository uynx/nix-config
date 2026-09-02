{
  # The macOS half of the AI tooling. Nothing is pinned here: the pins in
  # linux.nix are Linux artifacts, and every vendor that ships a macOS
  # build ships it through Homebrew, which greedyCasks keeps current on every
  # rebuild.
  flake.darwinModules.aiTools.homebrew = {
    brews = [
      "opencode"
      # The same coding agent the Linux hosts pin. Not `kimi-cli`, which is a
      # different product — the Kimi platform agent, not the terminal one.
      "kimi-code"
      "hermes-agent"
      # The CLI, not the `openclaw` cask — that one is only OpenClaw.app.
      "openclaw-cli"
      "qwen-code"
    ];

    casks = [
      # The same agents the Linux host pins, as their vendor builds.
      "claude-code"
      "codex"
      "grok-build"
      "cursor-cli"
      "antigravity-cli"
      # The macOS delivery of t3 — there is no formula for its CLI half.
      "t3-code"
    ];
  };
}
