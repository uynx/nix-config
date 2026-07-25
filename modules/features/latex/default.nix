{
  # texlive comes from the stable channel to avoid constant recompiles.
  flake.homeModules.latex = { pkgs-stable, ... }: {
    home.packages = [
      (pkgs-stable.texlive.withPackages (
        ps: with ps; [
          scheme-full
          biber
        ]
      ))
    ];
  };
}
