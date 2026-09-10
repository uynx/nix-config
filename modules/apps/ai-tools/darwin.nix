{
  flake.darwinModules.aiTools.homebrew = {
    brews = [
      "opencode"
      "kimi-code"
      "hermes-agent"
      "openclaw-cli"
      "qwen-code"
    ];

    casks = [
      "claude-code"
      "codex"
      "grok-build"
      "cursor-cli"
      "antigravity-cli"
      "t3-code"
    ];
  };
}
