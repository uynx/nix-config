{ self, ... }:
{
  # Every macOS preference this config asserts. No NixOS counterpart exists.
  # The firewall, lock screen and login window are not preferences and live in
  # ./security.nix, mirroring `system/security.nix`.
  flake.darwinModules.defaults = {
    system = {
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };

      startup.chime = false;

      defaults = {
        # Safari, Siri, TextEdit, mail and QuickTimePlayerX are sandboxed: `defaults`
        # redirects those writes into ~/Library/Containers, so activation only
        # succeeds from a terminal holding Full Disk Access, and a fresh grant needs
        # that terminal relaunched before it applies.
        CustomUserPreferences = {
          "com.apple.CrashReporter".DialogType = "none";
          "com.apple.universalaccess".reduceMotion = true;
          "com.apple.assistant.support" = {
            "Assistant Enabled" = false;
            "Dictation Enabled" = false;
          };
          "com.apple.Siri" = {
            "Siri Data Sharing Opt-Out" = true;
            StatusMenuVisible = false;
            UserHasDeclinedEnable = true;
          };
          "com.apple.SubmitDiagnostics".iCloudAnalytics = false;
          "com.apple.AdLib" = {
            allowApplePersonalizedAdvertising = false;
            allowIdentifierForAdvertising = false;
            AD_ID_OPT_OUT = true;
          };
          "com.apple.Safari" = {
            UniversalSearchEnabled = false;
            PreloadTopHit = false;
            BlockStoragePolicy = 2;
            IncludeInternalDebugMenu = true;
            IncludeDevelopMenu = true;
            WebKitDeveloperExtrasEnabledPreferenceKey = true;
            "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
            ShowFullURLInSmartSearchField = true;
            AutoOpenSafeDownloads = false;
          };
          "com.apple.spotlight" = {
            SuggestionsEnabled = false;
            LookupEnabled = false;
          };
          "com.apple.LaunchServices".LSQuarantine = false;
          "com.apple.desktopservices" = {
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
          "com.apple.mail".DisableDataDetectors = true;
          "com.apple.TextEdit" = {
            RichText = 0;
            PlainTextEncoding = 4;
            PlainTextEncodingForWrite = 4;
          };
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
          AppleShowAllFiles = false;
          AppleKeyboardUIMode = 3;
          AppleInterfaceStyle = "Dark";
          AppleICUForce24HourTime = false;
          _HIHideMenuBar = true;

          NSAutomaticWindowAnimationsEnabled = false;

          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          NSAutomaticInlinePredictionEnabled = false;

          NSWindowShouldDragOnGesture = true; # Cmd + Ctrl + click anywhere to drag

          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
          PMPrintingExpandedStateForPrint = true;
          PMPrintingExpandedStateForPrint2 = true;
          AppleScrollerPagingBehavior = true; # Jump to the spot clicked on the bar
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
          location = "${self.lib.user.darwinHome}/Pictures";
          type = "png";
        };
      };
    };

    power = {
      restartAfterFreeze = true;
      sleep.allowSleepByPowerButton = true;
    };
  };
}
