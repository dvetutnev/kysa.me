{
  description = "The static blog kysa.me";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkSite = pkgs.callPackage ./site.nix { };
          mkJSON = pkgs.callPackage ./extract_image_path.nix { };
        in
        {
          site = mkSite "http://localhost:8080/";
          docJSON = mkJSON ./t.md;
        }
      );

      lib = forAllSystems (
        system:
        let
          inherit (self.packages.${system}) docJSON;
          doc = builtins.fromJSON (builtins.readFile docJSON);
          allImageEntries = builtins.filter (e: e.t == "Figure") doc.blocks;
          imEntry = builtins.head allImageEntries;
          imContThrid = builtins.elemAt imEntry.c 2;
          imContThridObj = builtins.head imContThrid;
          imContThridObjCont = builtins.head imContThridObj.c;
          imContThridObjContThrid = builtins.elemAt imContThridObjCont.c 2;
          imPath = builtins.head imContThridObjContThrid;
        in
        {
          inherit doc;
          inherit allImageEntries;
          inherit imEntry;
          inherit imContThrid;
          inherit imContThridObj;
          inherit imContThridObjCont;
          inherit imContThridObjContThrid;
          inherit imPath;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkSite = pkgs.callPackage ./site.nix { };
          www_root = mkSite "http://localhost:8080/";
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
          default = {
            type = "app";
            program = nixpkgs.lib.getExe previewServer;
          };
        }
      );
    };
}
