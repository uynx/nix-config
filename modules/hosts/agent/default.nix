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
      plasma
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
            rustdesk
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
          services.xserver = {
            enable = true;
            videoDrivers = [ "nvidia" ];
            # No monitor is ever attached; without this nvidia creates no display at all.
            deviceSection = ''
              Option "AllowEmptyInitialConfiguration" "true"
            '';
          };

          services.desktopManager.plasma6.enable = true;
          services.displayManager.sddm = {
            enable = true;
            # KWin implements the Wayland RemoteDesktop portal niri lacks; this is why RustDesk needs Plasma at all.
            wayland.enable = true;
          };
          services.displayManager.autoLogin = {
            enable = true;
            user = self.lib.user.name;
          };

          sops.secrets.agent-data-key = { };
          sops.secrets.agent-uynx-password.neededForUsers = true;
          users.users.${self.lib.user.name}.hashedPasswordFile =
            config.sops.secrets.agent-uynx-password.path;
          environment.etc.crypttab.text = ''
            cryptdata /dev/disk/by-partlabel/disk-data-luks ${config.sops.secrets.agent-data-key.path} nofail
          '';

          services.logind.settings.Login.HandleLidSwitch = "ignore";

          # This box runs unattended and must never sleep.
          systemd.sleep.settings.Sleep.AllowSuspend = false;

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
