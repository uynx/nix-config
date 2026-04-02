{
  inputs,
  pkgs,
  pkgs-stable,
  config,
  ...
}:

{
  users.users.uynx.home = "/Users/uynx";

  determinateNix = {
    enable = true;
    determinateNixd = {
      garbageCollector.strategy = "automatic";
    };
    customSettings = {
      auto-optimise-store = true;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bak";
    users.uynx = import ./home.nix;
    sharedModules = [
      inputs.mac-app-util.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
    ];
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
      CustomUserPreferences = {
        "com.apple.CrashReporter" = {
          DialogType = "none";
        };
        "com.apple.assistant.support" = {
          "Assistant Enabled" = false;
          "Dictation Enabled" = false;
        };
        "com.apple.Siri" = {
          "Siri Data Sharing Opt-Out" = true;
          "StatusMenuVisible" = false;
          "UserHasDeclinedEnable" = true;
        };
        "com.apple.SubmitDiagnostics" = {
          iCloudAnalytics = false;
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
          allowIdentifierForAdvertising = false;
          AD_ID_OPT_OUT = true;
        };
        "com.apple.Safari" = {
          UniversalSearchEnabled = false;
          PreloadTopHit = false;
          SendDoNotTrackHTTPHeader = true;
          BlockStoragePolicy = 2;
          IncludeInternalDebugMenu = true;
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
          ShowFullURLInSmartSearchField = true;
        };
        "com.apple.spotlight" = {
          SuggestionsEnabled = false;
          LookupEnabled = false;
        };
        "com.apple.LaunchServices" = {
          LSQuarantine = false;
        };
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.TimeMachine" = {
          DoNotOfferNewDisksForBackup = true;
        };
        "com.apple.mail" = {
          DisableDataDetectors = true;
        };
        "com.apple.TextEdit" = {
          RichText = 0;
          PlainTextEncoding = 4;
          PlainTextEncodingForWrite = 4;
        };
        "com.apple.Safari".AutoOpenSafeDownloads = false;
        "com.apple.finder" = {
          WarnOnEmptyTrash = false;
          DisableAllAnimations = true;
        };
        "com.apple.frameworks.diskimages" = {
          skip-verify = true;
          skip-verify-locked = true;
          skip-verify-remote = true;
        };
        "com.apple.QuickTimePlayerX" = {
          NSRecentDocumentsLimit = 0;
          NSQuitAlwaysKeepsWindows = false;
        };
      };

      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      smb = {
        NetBIOSName = "Mac";
        ServerDescription = "Mac";
      };

      NSGlobalDomain = {
        KeyRepeat = 5;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        "com.apple.mouse.tapBehavior" = 1;
        AppleShowAllExtensions = true;
        AppleInterfaceStyle = "Dark";
        AppleICUForce24HourTime = false;

        NSAutomaticWindowAnimationsEnabled = false;

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
        NSDocumentSaveNewDocumentsToCloud = false;
        NSWindowResizeTime = 0.001;
      };

      WindowManager = {
        EnableStandardClickToShowDesktop = false;
        StandardHideDesktopIcons = true;
      };

      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        show-recents = false;
        launchanim = false;
        mouse-over-hilite-stack = true;
        orientation = "right";
        tilesize = 48;
        showhidden = true;
        static-only = true;
        mineffect = "scale";
        minimize-to-application = true;
        show-process-indicators = true;
        mru-spaces = false;
        wvous-br-corner = 13; # Lock Screen
        expose-animation-duration = 0.0;
      };

      finder = {
        _FXSortFoldersFirst = true;
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf";
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        QuitMenuItem = true;
        CreateDesktop = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };

      screencapture = {
        location = "${config.users.users.uynx.home}/Pictures/Screenshots";
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
