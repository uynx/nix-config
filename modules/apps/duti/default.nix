{
  # macOS keeps file associations in Launch Services, which has no declarative
  # interface — duti is the only way to set them from a config.
  flake.homeModules.duti =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.duti ];

      home.activation.setFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        duti=${lib.getExe pkgs.duti}
        "$duti" -s com.vscodium public.plain-text all
        "$duti" -s com.vscodium net.daringfireball.markdown all
        # Extensions Launch Services has no UTI for; failures are expected and
        # must not fail the activation.
        for ext in txt md markdown nix json yaml yml toml sh py cpp h; do
          "$duti" -s com.vscodium "$ext" all 2>/dev/null || true
        done
      '';
    };
}
