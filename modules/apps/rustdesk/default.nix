{ inputs, ... }:
{
  # Remote desktop. macOS takes the Homebrew cask (darwin.nix beside this);
  # Linux takes the Flathub build rather than nixpkgs' `rustdesk`, which is a
  # deliberate choice and not an oversight — revisit only if asked.
  #
  # nixpkgs' `services.flatpak.enable` installs the daemon and stops there: it
  # declares no remote and no application. The RustDesk that lived here before
  # the reinstall was therefore a hand-run `flatpak install`, which is exactly
  # why it did not come back. `nix-flatpak` adds the missing half.
  #
  # This module owns flatpak outright, rather than leaning on the desktop
  # enabling it, so that a host taking `comms` without a desktop still works.
  flake.nixosModules.rustdesk = {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      enable = true;

      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      packages = [ "com.rustdesk.RustDesk" ];

      # Flatpak refs carry no hash, so "reproducible" here means the app is
      # always installed and always from a declared remote — not that two
      # machines built from one commit get identical bytes. Updating on
      # activation keeps that drift bounded to a rebuild rather than letting it
      # accumulate silently, and matches how the Homebrew side is kept current.
      update.onActivation = true;
    };
  };
}
