{ self, inputs, ... }:
{
  flake.nixosConfigurations.x86 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      standard
      siteBlock
      aoa
      hardwareX86
      unattended

      # `reb switch` flips ./desktop between niri and kde, then rebuilds and reboots.
      (if builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./desktop) == "kde" then desktopKde else desktopNiri)
      (self.lib.gaming "native")

      inputs.lanzaboote.nixosModules.lanzaboote
      ./_hardware-configuration.nix

      {
        networking.hostName = "x86";
        security.sudo.wheelNeedsPassword = false;
      }
      # The login keyring's password is blank, or autologin leaves it locked and Brave prompts.
      {
        services.displayManager.autoLogin = {
          enable = true;
          user = self.lib.user.name;
        };
      }
      {
        home-manager.users.${self.lib.user.name} =
          { config, ... }:
          {
            # Noctalia merges its folder's *.toml alphabetically, so this must sort after config.toml.
            xdg.configFile."noctalia/host.toml".source =
              config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/modules/apps/noctalia/x86.toml";
          };
      }
      {
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      }
      {
        # Uncapped turbo hit 93°C within 3 min at full load (reset unclean twice at 95-98°C); 89% held 84°C in the test but spiked to 92°C under jobs; 84% (L7-54, 2026-11-11).
        systemd.tmpfiles.rules = [
          "w /sys/devices/system/cpu/intel_pstate/no_turbo - - - - 0"
          "w /sys/devices/system/cpu/intel_pstate/max_perf_pct - - - - 84"
        ];
      }
      {
        # memory_recursiveprot caps aoa-live.slice's MemoryLow (always_on_agent ops/run.sh, 30% of RAM) at every ancestor's; with none here the live arms got no protection from the jobs.
        systemd.slices = {
          user = {
            overrideStrategy = "asDropin";
            sliceConfig.MemoryLow = "12G";
          };
          "user-1000" = {
            overrideStrategy = "asDropin";
            sliceConfig.MemoryLow = "12G";
          };
        };
        systemd.services."user@1000" = {
          overrideStrategy = "asDropin";
          restartIfChanged = false;
          serviceConfig.MemoryLow = "12G";
        };
      }
      {
        services.udev.extraRules = ''
          SUBSYSTEM=="leds", KERNEL=="phy0-led", ATTR{trigger}="none", ATTR{brightness}="0"
        '';
      }
      (
        let
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUYRYdgXB3O1EvWT1v9pohkK5ylBjpw2aBDViQTia7c";
        in
        {
          services.openssh = {
            enable = true;
            openFirewall = false;
            settings.PasswordAuthentication = false;
            settings.KbdInteractiveAuthentication = false;
            settings.PermitRootLogin = "no";
          };
          users.users.${self.lib.user.name}.openssh.authorizedKeys.keys = [ key ];
        }
      )
    ];
  };
}
