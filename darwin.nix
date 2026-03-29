{ inputs, pkgs, ... }:

{
  users.users.uynx.home = "/Users/uynx";

  # Using Determinate Nix
  nix.enable = false;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

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

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bak";
    users.uynx = import ./home.nix;
    extraSpecialArgs = {
      inherit inputs;
      pkgs-stable = import inputs.nixpkgs-stable {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };
    };
  };

  system = {
    primaryUser = "uynx";

    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    stateVersion = 6;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 5;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        "com.apple.mouse.tapBehavior" = 1;
        AppleShowAllExtensions = true;
        AppleInterfaceStyle = "Dark";
        AppleICUForce24HourTime = false;

        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;

        NSWindowShouldDragOnGesture = true; # Cmd + Ctrl + Click anywhere to drag windows

        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        AppleScrollerPagingBehavior = true; # Jump to the spot clicked on the scroll bar
      };

      WindowManager = {
        EnableStandardClickToShowDesktop = false; # Stop hiding windows when clicking wallpaper
        StandardHideDesktopIcons = true;
      };

      dock = {
        autohide = true;
        show-recents = false;
        launchanim = false;
        mouse-over-hilite-stack = true;
        orientation = "bottom";
        tilesize = 48;
        showhidden = true; # Translucent icons for hidden apps
      };

      finder = {
        _FXSortFoldersFirst = true;
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf"; # Search current folder by default
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
      };

      screencapture = {
        location = "~/Pictures/Screenshots";
        type = "png";
      };
    };

    startup.chime = false;
  };

  environment = {
    shells = [
      pkgs.fish
      pkgs.dash
      pkgs.bashInteractive
    ];
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
      "protonvpn"
      "streamlabs"
      "mullvad-browser"
    ];
    masApps = {
      "cakewallet" = 1334702542;
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

  programs.fish.enable = true;
  programs.bash.enable = true;
  users.users."uynx".shell = pkgs.fish;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
}
