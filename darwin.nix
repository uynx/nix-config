{ config, lib, inputs, pkgs, ... }:

{  
  users.users.uynx.home = "/Users/uynx";

  # Using Determinate Nix
  nix.enable = false;

  launchd.daemons = {
    nix-gc = {
      script = "exec /nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 14d";
      serviceConfig = {
        StartCalendarInterval = [{ Hour = 4; Minute = 0; }];
        StandardErrorPath = "/var/log/nix-gc.log";
        StandardOutPath = "/var/log/nix-gc.log";
      };
    };

    nix-optimise = {
      script = "exec /nix/var/nix/profiles/default/bin/nix store optimise";
      serviceConfig = {
        StartCalendarInterval = [{ Hour = 4; Minute = 0; }];
        StandardErrorPath = "/var/log/nix-optimise.log";
        StandardOutPath = "/var/log/nix-optimise.log";
      };
    };
  };

  launchd.user.agents = {
    nix-gc-user = {
      command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 14d";
      serviceConfig = {
        StartCalendarInterval = [{ Hour = 4; Minute = 0; }];
        StandardErrorPath = "/Users/uynx/Library/Logs/nix-gc-user.log";
        StandardOutPath = "/Users/uynx/Library/Logs/nix-gc-user.log";
      };
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bak";
    users.uynx = import ./home.nix;
    extraSpecialArgs = { inherit inputs; };
  };

  system = {
    primaryUser = "uynx";

    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    stateVersion = 6;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    startup.chime = false;
  };

  environment = {
    systemPackages = with pkgs; [
      duti
      docker
      colima
      lima
      postgresql
      mongodb-tools
    ];
    shellAliases = {
      update = "nix flake update --flake ~/nix-config";
      reb = "sudo darwin-rebuild switch --flake ~/nix-config#macos";
      unb = "xattr -d com.apple.quarantine";
    };
    shells = [ pkgs.fish ];
  };

  homebrew = {
    enable = true;
    greedyCasks = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    casks = [ 
      "julia-app"
      "skim"
      "microsoft-office" 
      "tor-browser"
      "mullvad-browser"
      "protonvpn"
      "streamlabs"
      "obs"
    ];
    caskArgs = {
      no_quarantine = true;
    };
  };

  fonts.packages = [ pkgs.nerd-fonts.hack ];

  networking = {
    applicationFirewall.enable = true;
    applicationFirewall.enableStealthMode = true;
    computerName = "MacBook-Pro";
    hostName = "MacBook-Pro";
    # wakeOnLan.enable = true;
  };

  power = {
    restartAfterFreeze = true;
    sleep.allowSleepByPowerButton = true;
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
  
  programs.fish.enable = true;
  users.users."uynx".shell = pkgs.fish;
}
