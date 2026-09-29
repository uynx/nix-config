{
  flake.darwinModules.aiTools.homebrew = {
    brews = [
    ];

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
          "antigravity-cli"
        ]
      ++ [ "t3-code" ];
  };
}
