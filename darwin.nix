{ inputs, pkgs, ... }:

{
  users.users.uynx.home = "/Users/uynx";

  # Using Determinate Nix
  nix.enable = false;

  launchd.daemons = {
    nix-gc = {
      script = "exec /nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 3d";
      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 0;
          }
        ];
        StandardErrorPath = "/var/log/nix-gc.log";
        StandardOutPath = "/var/log/nix-gc.log";
      };
    };

    nix-optimise = {
      script = "exec /nix/var/nix/profiles/default/bin/nix store optimise";
      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 0;
          }
        ];
        StandardErrorPath = "/var/log/nix-optimise.log";
        StandardOutPath = "/var/log/nix-optimise.log";
      };
    };
  };

  launchd.user.agents = {
    nix-gc-user = {
      command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 3d";
      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 0;
          }
        ];
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

    defaults.NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 5;
      InitialKeyRepeat = 15;
    };

    startup.chime = false;
  };

  environment = {
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
      "libreoffice"
      "skim"
      "protonvpn"
      "streamlabs"
      "tor-browser"
      "mullvad-browser"
      "obs"
    ];
    masApps = {
      "Cake Wallet" = 1334702542;
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    julia-mono
  ];

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
