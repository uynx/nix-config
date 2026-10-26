{ self, inputs, ... }:
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUYRYdgXB3O1EvWT1v9pohkK5ylBjpw2aBDViQTia7c";
  user = self.lib.user.name;
in
{
  flake.nixosConfigurations.agent = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      standard
      # `reb switch` flips ./desktop between niri and kde; kde because RustDesk needs KWin's RemoteDesktop portal.
      (if builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./desktop) == "kde" then desktopKde else desktopNiri)
      (self.lib.gaming "native")

      inputs.disko.nixosModules.disko
      ./_disko.nix
      ./_hardware-configuration.nix

      (
        { config, pkgs, ... }:
        {
          networking.hostName = "agent";
          nixpkgs.hostPlatform = "x86_64-linux";

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

          # Unattended box: RustDesk needs a logged-in session, and it must never sleep.
          services.displayManager.autoLogin = {
            enable = true;
            inherit user;
          };
          systemd.sleep.settings.Sleep.AllowSuspend = false;
          services.logind.settings.Login.HandleLidSwitch = "ignore";

          # Autologin types no password, so an encrypted login keyring would prompt on every boot.
          home-manager.users.${user} =
            { config, lib, ... }:
            {
              programs.plasma.kscreenlocker = {
                autoLock = false;
                lockOnResume = false;
              };

              home.activation.plainLoginKeyring = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                k=${config.home.homeDirectory}/.local/share/keyrings/login.keyring
                [ -e "$k" ] || run install -Dm600 ${pkgs.writeText "login.keyring" ''
                  [keyring]
                  display-name=login
                  ctime=0
                  mtime=0
                  lock-on-idle=false
                  lock-after=false
                ''} "$k"
              '';
            };

          sops.secrets.agent-data-key = { };
          environment.etc.crypttab.text = ''
            cryptdata /dev/disk/by-partlabel/disk-data-luks ${config.sops.secrets.agent-data-key.path} nofail
          '';

          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = false;
          };
          users.users.root.openssh.authorizedKeys.keys = [ key ];
          users.users.${user}.openssh.authorizedKeys.keys = [ key ];

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 50;
          };

          swapDevices = [
            {
              device = "/swapfile";
              size = 32768;
            }
          ];
        }
      )
    ];
  };
}
