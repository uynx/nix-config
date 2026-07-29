{
  flake.homeModules.braveOrigin =
    { pkgs, ... }:

    let
      update-brave-origin = pkgs.writers.writePython3Bin "update-brave-origin" { } ''
        import os
        import re
        import subprocess
        import urllib.request

        base = "https://brave-browser-apt-release.s3.brave.com"
        url = f"{base}/dists/stable/main/binary-arm64/Packages"
        idx = urllib.request.urlopen(url).read().decode()
        pat = r"Package: brave-origin\n.*?Version: ([\d.]+)"
        latest = re.search(pat, idx, re.DOTALL).group(1)
        # Split: writePython3Bin runs a PEP8 check and E501 fires at 79 chars.
        rel = "modules/features/brave-origin/_brave-origin.nix"
        path = os.path.expanduser(f"~/nixos-config/{rel}")
        text = open(path).read()
        cur = re.search(r'version = "([\d.]+)";', text).group(1)
        print(f"Current: {cur} | Latest: {latest}")
        if cur == latest:
            print("Already up to date.")
            raise SystemExit(0)


        def h(arch):
            url = (
                f"{base}/pool/main/b/brave-origin/"
                f"brave-origin_{latest}_{arch}.deb"
            )
            print(f"Hashing {arch}...")
            cmd = ["nix-prefetch-url", url]
            pf = subprocess.run(
                cmd, capture_output=True, text=True, check=True
            )
            cmd_convert = [
                "nix", "hash", "convert",
                "--hash-algo", "sha256",
                "--to", "sri",
                pf.stdout.strip()
            ]
            return subprocess.run(
                cmd_convert, capture_output=True, text=True, check=True
            ).stdout.strip()


        arm, amd = h("arm64"), h("amd64")
        text = re.sub(r'version = "[^"]+";', f'version = "{latest}";', text)
        text = re.sub(
            r'hash = if arch == "arm64" then "[^"]+"\s+else "[^"]+";',
            f'hash = if arch == "arm64" then "{arm}"\n         else "{amd}";',
            text,
        )
        open(path, "w").write(text)
        print("Updated brave-origin.nix successfully!")
      '';

    in
    {
      home.packages = [ update-brave-origin ];

      programs.chromium = {
        enable = true;
        package = pkgs.callPackage ./_brave-origin.nix { };
      };
    };
}
