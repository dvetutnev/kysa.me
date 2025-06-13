{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    {
      packages."x86_64-linux".default =
        let
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          mkPage = pkgs.callPackage ./mk-page.nix { };
          www_root = mkPage {
            path = ./content/test.md;
            prefix = ./content;
          };
        in
        www_root;

      apps."x86_64-linux".default =
        let
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          www_root = self.packages."x86_64-linux".default;
          config = pkgs.writeTextDir "Caddyfile" ''
            http://localhost:8080

            header +Cache-Control "no-cache, no-store, must-revalidate"

            log

            root * ${www_root}
            file_server
          '';
          previewServer = pkgs.writeShellApplication {
            name = "server";
            runtimeInputs = [ pkgs.caddy ];
            text = "caddy run --config ${config}/Caddyfile";
          };
        in
        {
          type = "app";
          program = nixpkgs.lib.getExe previewServer;
        };
    };
}
