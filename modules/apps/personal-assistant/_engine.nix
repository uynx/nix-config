{ root }:
builtins.path {
  path = root;
  name = "assistant-engine";
  filter =
    path: type:
    let
      name = baseNameOf path;
    in
    builtins.match "\\.env(\\..*)?" name == null
    && !(builtins.elem name [
      ".git"
      ".direnv"
      "result"
      ".env"
      ".env.local"
      "__pycache__"
    ])
    && (
      builtins.substring 0 (builtins.stringLength "${root}/node_modules/") path == "${root}/node_modules/"
      || type == "directory"
      || builtins.match ".*\\.(ts|js|mjs|cjs|json|md|py|sh|toml|node|map|wasm|so|d\\.ts)" name != null
      || builtins.elem name [
        "bun.lock"
        "secrets.enc.yaml"
      ]
    );
}
