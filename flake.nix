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

              mkNavLink = { urn, name }: ''<li><a href="${siteUrl}${urn}">${name}</a></li>'';

              mkIncludeBefore = navLinks: ''
                <div class="sidebar">
                  <div class="container sidebar-sticky">
                    <div class="sidebar-about">
                      <h1>kysa.me</h1>
                      <p class="lead">&Zcy;&acy;&mcy;&iecy;&tcy;&ocy;&chcy;&kcy;&icy;</p>
                    </div>

                    <ul class="sidebar-nav">
                      ${navLinks}
                    </ul>

                    <p>&copy; 2017. All rights reserved.</p>
                  </div>
                </div>'';

              nav_links = lib.strings.concatStrings (
                map mkNavLink [
                  {
                    urn = "README.md.html";
                    name = "Home";
                  }
                  {
                    urn = "";
                    name = "About";
                  }
                ]
              );

              include_before = mkIncludeBefore nav_links;

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
