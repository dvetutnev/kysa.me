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

      _mkSite =
        {
          runCommand,
          writeTextDir,
          symlinkJoin,
          pandoc,
          lib,
        }:
        siteUrl:

        let
          css = [
            ./css/poole.css
            ./css/syntax.css
            ./css/hyde.css
            ./css/hyde-styx.css
            "https://fonts.googleapis.com/css?family=PT+Sans:400,400italic,700|Abril+Fatface"
          ];

          index_html = writeTextDir "index.html" ''
            <!DOCTYPE html>
            <html>
            <body>
            <p>Hello world!</p>
            </body>
            </html>
          '';

          addFile = file: writeTextDir (lib.path.removePrefix ./. file) (builtins.readFile file);

          page =
            file:
            let
              template = ./default.html5;

              include_before = ''
                <div class="sidebar">
                  <div class="container sidebar-sticky">
                    <div class="sidebar-about">
                      <a href="https://styx-static.github.io/styx-theme-hyde/"><h1>Styx Site</h1></a>
                      <p class="lead">An elegant open source and mobile first theme for styx made by <a href="http://twitter.com/mdo">@mdo</a>. Originally made for Jekyll.
                </p>
                    </div>

                    <ul class="sidebar-nav">
                      <li><a href="${siteUrl}README.md.html/">Home</a></li>
                      <li><a href="${siteUrl}">About</a></li>

                    </ul>

                    <p>&copy; 2017. All rights reserved. 
                </p>
                  </div>
                </div>'';

              removeCurrentDirPrefix =
                filePath: lib.strings.removePrefix "./" (lib.path.removePrefix ./. filePath);

              name = removeCurrentDirPrefix file;

              makeCSSArg =
                cssPath:
                let
                  res = if builtins.isPath cssPath then siteUrl + (removeCurrentDirPrefix cssPath) else cssPath;
                in
                lib.escapeShellArg "--css=${res}";

              cssArgs = lib.concatStringsSep " " (map makeCSSArg css);

            in
            runCommand name { } ''
              target=$out/${lib.escapeShellArg name}.html
              mkdir -p "$(dirname "$target")"
              echo ">>>>>taRGET----"
              echo "$target"
              echo "${file}"
              echo "${cssArgs}"
              ${lib.getExe pandoc} --standalone \
                                   --template=${template} \
                                   --to=html5 \
                                   --output="$target" \
                                   ${cssArgs} \
                                   --variable=include-before:${lib.escapeShellArg include_before} \
                                   ${file} \
                                   --verbose
            '';

        in
        symlinkJoin {
          name = "www_root";
          paths = [
            index_html
            (page ./README.md)
          ] ++ map (p: addFile p) (builtins.filter (x: builtins.isPath x) css);
        };

    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkSite = pkgs.callPackage _mkSite { };
        in
        {
          site = mkSite "http://localhost:8080/";
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkSite = pkgs.callPackage _mkSite { };
          www_root = mkSite "http://localhost:8080/";
          previewServer = pkgs.writeShellApplication {
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
        }
      );
    };
}
