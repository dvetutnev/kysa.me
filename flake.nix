{
  description = "The static blog kysa.me";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;


      _mkSite = { writeText, writeTextDir, symlinkJoin, linkFarmFromDrvs }:
        url:
        let
          index_html = writeTextDir "index.html"
          ''
          <!DOCTYPE html>
          <html>
          <body>
          <p>Hello world!</p>
          </body>
          </html>
          '';
          css = writeTextDir "css/hyde.css"
            (builtins.readFile ./css/hyde.css);
        in
          symlinkJoin {
            name = "www_root";
            paths = [
              index_html
              css
            ];
          };

    in
      {
        packages = forAllSystems (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            mkSite = pkgs.callPackage _mkSite {};
          in
            {
              site = mkSite "http://localhost:8080/";
            });
        
      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          site = pkgs.callPackage _mkSite {};
          www_root = site "http://localhost:8080/";
          previewServer = pkgs.writeShellApplication
            {
              name = "server";
              runtimeInputs = [ pkgs.caddy ];
              text = "caddy file-server --listen 127.0.0.1:8080 --root ${www_root}";
            };
        in
        {
          default = {
            type = "app";
            program = nixpkgs.lib.getExe previewServer;
          };
        });
    };
}
