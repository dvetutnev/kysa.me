{
  description = "The static blog kysa.me";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        {
          default = nixpkgs.legacyPackages.${system}.writeTextDir "index.html"
          ''
          <html>
          </html>
          '';
        });

      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          previewServer = pkgs.writeShellApplication
            {
              name = "server";
              runtimeInputs = [ pkgs.caddy ];
              text = "caddy --version";
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
