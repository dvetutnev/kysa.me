{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    {
      apps."x86_64-linux".default =
        let
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          www_root = pkgs.writeTextDir "index.html" ''
            <!DOCTYPE html>
            <html>
            <head>
                <title>Hello World</title>
            </head>
            <body>
                <h1>Hello World</h1>
            </body>
            </html>
          '';
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
