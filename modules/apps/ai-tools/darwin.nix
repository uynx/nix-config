{
  flake.darwinModules.aiTools.homebrew = {
    brews = [
      "opencode"
      "kimi-code"
      "hermes-agent"
      "openclaw-cli"
      "qwen-code"
    ];

    # Bare executables cannot staple a ticket, so quarantine blocks them offline.
    casks =
      map
        (name: {
          inherit name;
          args.no_quarantine = true;
        })
        [
          "claude-code"
          "codex"
          "grok-build"
          "cursor-cli"
          "antigravity-cli"
        ]
      ++ [ "t3-code" ];
  };
}
