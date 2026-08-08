{
  # LibreOffice has no darwin build in nixpkgs — only the Linux one. Obsidian
  # does, so it stays in the shared home module.
  flake.darwinModules.officeCasks = {
    homebrew.casks = [ "libreoffice" ];
  };
}
