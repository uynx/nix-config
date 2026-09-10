{
  flake.homeModules.duti =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.duti ];

      home.activation.setFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        duti=${lib.getExe pkgs.duti}
        "$duti" -s com.vscodium public.plain-text all
        "$duti" -s com.vscodium net.daringfireball.markdown all
        for ext in txt md markdown nix json yaml yml toml sh py cpp h; do
          "$duti" -s com.vscodium "$ext" all 2>/dev/null || true
        done
      '';
    };
}
