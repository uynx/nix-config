{
  # The macOS half of the AI tooling. Nothing is pinned here: the pins in
  # linux.nix are aarch64-linux artifacts, and every vendor that ships a macOS
  # build ships it through Homebrew, which greedyCasks keeps current on every
  # rebuild. kimi is the exception and is fetched by `update-ai-clis`.
  flake.darwinModules.aiTools.homebrew = {
    brews = [
      "opencode"
    ];

    casks = [
      # The same agents the Linux host pins, as their vendor builds.
      "claude-code"
      "codex"
      "grok-build"
      "cursor-cli"
      "antigravity-cli"

      # Desktop apps, which have no Linux counterpart worth packaging.
      "claude"
      "chatgpt"
      "cursor"
      "antigravity"
      "kimi"
    ];
  };
}
