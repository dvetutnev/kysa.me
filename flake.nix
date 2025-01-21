{
  description = "The static blog kysa.me";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      index_html = system:
        nixpkgs.legacyPackages.${system}.writeText "index.html"
          ''
          <!DOCTYPE html>
          <html>
          <body>
          <p>Hello world!</p>
          </body>
          </html>
          '';
    in
    {
      packages = forAllSystems (system:
        {
          default = nixpkgs.legacyPackages.${system}.linkFarmFromDrvs "www_root"
            [
              (index_html system)
            ];
        });

      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          www_root = self.packages.${system}.default;
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
