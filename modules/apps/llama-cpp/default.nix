{
  # Local LLM inference. Vulkan is the only accelerated backend that exists here:
  # Metal is macOS-only, and ollama's GPU support is amd64-only, so on Asahi it
  # would be CPU-bound. Mesa already ships `libvulkan_asahi.so`, so nothing else
  # is needed to reach the GPU.
  flake.homeModules.llamaCpp =
    { pkgs, ... }:
    let
      version = "10353";
    in
    {
      home.packages = [
        # nixpkgs sits at b10121, which predates the Muse Glimmer architecture
        # (merged upstream 2026-08-10). Bumping the source alone keeps the rest
        # of the flake pinned where it is.
        ((pkgs.llama-cpp.override { vulkanSupport = true; }).overrideAttrs {
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
        })
      ];
    };
}
