{
  flake.homeModules.firefox =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.firefox.override {
          extraPolicies = {
            DisableTelemetry = true;
            DisableFirefoxStudies = true;
            DisablePocket = true;
            DisableFirefoxAccounts = true;
            DisableFeedbackCommands = true;
            DisableAppUpdate = true;
            DontCheckDefaultBrowser = true;
            NoDefaultBookmarks = true;
            OverrideFirstRunPage = "";
            OverridePostUpdatePage = "";
            UserMessaging = {
              ExtensionRecommendations = false;
              FeatureRecommendations = false;
              SkipOnboarding = true;
              MoreFromMozilla = false;
            };
            FirefoxHome = {
              SponsoredTopSites = false;
              SponsoredPocket = false;
              Pocket = false;
            };
            FirefoxSuggest = {
              SponsoredSuggestions = false;
              WebSuggestions = false;
              ImproveSuggest = false;
            };
          };
        })
      ];
    };
}
