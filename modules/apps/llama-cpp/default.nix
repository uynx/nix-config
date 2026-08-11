{
  # Local LLM inference. Vulkan is the only accelerated backend that exists here:
  # Metal is macOS-only, and ollama's GPU support is amd64-only, so on Asahi it
  # would be CPU-bound. Mesa already ships `libvulkan_asahi.so`, so nothing else
  # is needed to reach the GPU.
  #
  # The models themselves (~/models, ~60 GB of GGUFs) are fetched by
  # `~/ai_memory/scripts/llm_models.py` and deliberately stay out of the store;
  # only the router service and its launch-time flags are declared here.
  flake.homeModules.llamaCpp =
    { pkgs, ... }:
    let
      version = "10353";
      # nixpkgs sits at b10121, which predates the Muse Glimmer architecture
      # (merged upstream 2026-08-10). Bumping the source alone keeps the rest
      # of the flake pinned where it is.
      llamaServer = (pkgs.llama-cpp.override { vulkanSupport = true; }).overrideAttrs {
        inherit version;
        # Moves with the source: the bundled web UI's package-lock.json is
        # part of the tree being bumped.
        npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          rev = "refs/tags/b${version}";
          hash = "sha256-MQP91lL8zQLYcnYw5GlkMvH5sXiES+C6L4/1G3Y6TPY=";
        };
      };
    in
    {
      home.packages = [ llamaServer ];

      # opencode reaches the models through this provider config. Kept here
      # because it is purely about the local llama router: baseURL, the model
      # names the router serves, and per-model context limits that must match
      # the ctx-size in presets.ini (16384+4096 fits 24576 with compaction
      # headroom). Hand-editing ~/.config/opencode/opencode.jsonc will be
      # overwritten on the next rebuild — change this file instead.
      home.file.".config/opencode/opencode.jsonc".source = ./opencode.jsonc;

      # The router process. It is what opencode's provider config talks to on
      # 127.0.0.1:8080; presets.ini (managed by llm_models.py --presets) tells
      # it which model to load on demand, one resident at a time.
      systemd.user.services.llama-router = {
        Unit = {
          Description = "llama.cpp router for local opencode models";
          After = [ "default.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = ''
            ${llamaServer}/bin/llama-server --models-dir %h/models --models-max 1 \
              --models-preset %h/models/presets.ini --host 127.0.0.1 --port 8080
          '';
          Restart = "on-failure";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
