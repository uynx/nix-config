{ self, inputs, ... }:
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUYRYdgXB3O1EvWT1v9pohkK5ylBjpw2aBDViQTia7c";
in
{
  flake.nixosConfigurations.agent = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      homeManagerBase
      shell
      programming
      secrets
      privacy
      campus-wifi

      inputs.disko.nixosModules.disko
      ./_disko.nix
      ./_hardware-configuration.nix

      (
        { config, pkgs, ... }:
        {
          networking.hostName = "agent";
          nixpkgs.hostPlatform = "x86_64-linux";

          home-manager.users.${self.lib.user.name}.imports = with self.homeModules; [
            aiTools
            aiToolsPinned
            ungoogledChromium
          ];

          boot = {
            loader = {
              systemd-boot = {
                enable = true;
                configurationLimit = 10;
              };
              efi.canTouchEfiVariables = true;
            };
            kernelPackages = pkgs.linuxPackages_latest;
          };

          hardware = {
            enableRedistributableFirmware = true;
            graphics.enable = true;
            nvidia = {
              package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
              open = false;
              modesetting.enable = true;
            };
          };
          services.xserver.videoDrivers = [ "nvidia" ];

          services.logind.settings.Login.HandleLidSwitch = "ignore";

          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = false;
          };
          users.users.root.openssh.authorizedKeys.keys = [ key ];
          users.users.${self.lib.user.name}.openssh.authorizedKeys.keys = [ key ];

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 50;
          };
        }
      )
    ];
  };
}
