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

          t1 = pkgs.writeTextDir "posts/t1.md" "data1";
          i1 = pkgs.writeTextDir "posts/t1/pic.png" "png1";
          p1 = pkgs.symlinkJoin {
            name = "p1";
            paths = [
              t1
              i1
            ];
          };
          t2 = pkgs.writeTextDir "posts/t2.md" "data";
          i2 = pkgs.writeTextDir "posts/t2/pic.png" "png2";
          p2 = pkgs.symlinkJoin {
            name = "p2";
            paths = [
              t2
              i2
            ];
          };
          comp = pkgs.symlinkJoin {
            name = "comp";
            paths = [
              p1
              p2
            ];
          };
        in
        {
          site = mkSite "http://localhost:8080/";
          docJSON = mkJSON ./t.md;

          inherit t1 i1 p1;
          inherit t2 i2 p2;
          inherit comp;
        }
      );

      lib = forAllSystems (
        system:
        let
          inherit (self.packages.${system}) docJSON;
          doc = builtins.fromJSON (builtins.readFile docJSON);
        in
        rec {

          filterFigure =
            blocks:
            builtins.filter # /
              (e: e.t == "Figure")
              blocks;

          extractImagePathFromBlock =
            entry:
            let
              imContThrid = builtins.elemAt entry.c 2;
              imContThridObj = builtins.head imContThrid;
              imContThridObjCont = builtins.head imContThridObj.c;
              imContThridObjContThrid = builtins.elemAt imContThridObjCont.c 2;
              imPath = builtins.head imContThridObjContThrid;
            in
            imPath;

          picPaths =
            map (x: extractImagePathFromBlock x) # /
              (filterFigure doc.blocks);

          inherit doc;
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
