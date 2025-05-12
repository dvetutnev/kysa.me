{
  description = "The static blog kysa.me";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;


      _mkSite = { runCommand, writeTextDir, symlinkJoin, pandoc, lib }:
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

	  addFile = file: writeTextDir (lib.path.removePrefix ./. file)
            (builtins.readFile file);

	  page = file:
            let
	      name = lib.path.removePrefix ./. file;
	    in
              runCommand name {} ''
	      target=$out/${lib.escapeShellArg name}.html
              mkdir -p "$(dirname "$target")"
	      ls -la
echo ">>>>>taRGET"
echo "$target"
echo "wrrrrrite file"
echo "dddddd" > "$target"
echo "${file}"
              ${lib.getExe pandoc} --version 
	      '';
        in
          symlinkJoin {
            name = "www_root";
            paths = [
              index_html
	      (page ./README.md)
            ] ++ map (p: addFile p) [
	      ./css/poole.css
	      ./css/syntax.css
	      ./css/hyde.css
	      ./css/hyde-styx.css
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
