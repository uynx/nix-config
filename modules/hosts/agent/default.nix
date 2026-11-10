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
      aoa
      unattended
      personalAssistant
      # `reb switch` flips ./desktop between niri and kde; kde because RustDesk needs KWin's RemoteDesktop portal.
      (if builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./desktop) == "kde" then desktopKde else desktopNiri)
      (self.lib.gaming "native")

      inputs.disko.nixosModules.disko
      inputs.lanzaboote.nixosModules.lanzaboote
      ./_disko.nix
      ./_hardware-configuration.nix

      (
        { config, pkgs, ... }:
        {
          networking.hostName = "agent";
          nixpkgs.hostPlatform = "x86_64-linux";

          boot = {
            loader.efi.canTouchEfiVariables = true;
            # Keys enroll on the first boot with the firmware in Secure Boot setup mode.
            lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";
              configurationLimit = 10;
              autoGenerateKeys.enable = true;
              autoEnrollKeys.enable = true;
            };
            # TPM slot is enrolled by hand against PCR 7 once Secure Boot is on; the passphrase stays as fallback.
            initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];
            kernelPackages = pkgs.linuxPackages_latest;
            # MSI's DSDT throws harmless ACPI errors that print over the passphrase prompt.
            consoleLogLevel = 3;
          };
          environment.systemPackages = [ pkgs.sbctl ];
          security.sudo.wheelNeedsPassword = false;
          environment.variables.AGENT_OWNS_MACHINE = "1";

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
          # The wired card has no cable and its PCIe link logged a correctable error every 30 s; plugging one in needs this rule gone.
          services.udev.extraRules = ''
            ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1969", ATTR{device}=="0xe0b1", ATTR{remove}="1"
          '';
          # memory_recursiveprot caps aoa-live.slice's MemoryLow (always_on_agent ops/run.sh) at every ancestor's.
          systemd.slices = {
            user = {
              overrideStrategy = "asDropin";
              sliceConfig.MemoryLow = "5G";
            };
            "user-1000" = {
              overrideStrategy = "asDropin";
              sliceConfig.MemoryLow = "5G";
            };
          };
          systemd.services."user@1000" = {
            overrideStrategy = "asDropin";
            restartIfChanged = false;
            serviceConfig.MemoryLow = "5G";
          };
          # With turbo on the CPU sat at 95 to 97 C under the lanes' load, 3 C below its shutdown trip; off, it holds near 72 C.
          systemd.tmpfiles.rules = [ "w /sys/devices/system/cpu/intel_pstate/no_turbo - - - - 1" ];
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

              systemd.user.services.claude-agent = {
                Unit.Description = "Claude Code agent in tmux session 'agent'";
                Service = {
                  Type = "forking";
                  Environment = [
                    "AGENT_OWNS_MACHINE=1"
                    "PATH=/run/wrappers/bin:/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin"
                  ];
                  ExecStart = "/etc/profiles/per-user/${user}/bin/tmux new-session -d -s agent -c %h/always_on_agent 'claude --continue; exec fish'";
                  ExecStop = "/etc/profiles/per-user/${user}/bin/tmux kill-session -t agent";
                };
                Install.WantedBy = [ "default.target" ];
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
            openFirewall = false;
            settings.PasswordAuthentication = false;
            settings.KbdInteractiveAuthentication = false;
            settings.PermitRootLogin = "no";
          };
          users.users.${user} = {
            openssh.authorizedKeys.keys = [ key ];
            linger = true;
          };

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
