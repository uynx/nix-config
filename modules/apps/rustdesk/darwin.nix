{
  # Remote desktop, macOS only — the Linux hosts have no need to be driven
  # from another machine.
  flake.darwinModules.rustdesk = {
    homebrew.casks = [ "rustdesk" ];
  };
}
