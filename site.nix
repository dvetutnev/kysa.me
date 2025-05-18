{
  runCommand,
  stdenv,
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

  addFile =
    file:
    stdenv.mkDerivation rec {
      destName = removeCurrentDirPrefix file;

      name = "pic";
      src = file;

      buildCommand = ''
        echo 123
        echo $out
        echo "${file}"
        install -m 644 -D ${file} $out/${destName}
      '';
    };

  removeCurrentDirPrefix =
    filePath: lib.strings.removePrefix "./" (lib.path.removePrefix ./. filePath);

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
            urn = "README.html";
            name = "Home";
          }
          {
            urn = "pages/about.html";
            name = "About";
          }
        ]
      );

      include_before = mkIncludeBefore nav_links;

      name = builtins.replaceStrings [ ".md" ] [ ".html" ] (removeCurrentDirPrefix file);

      drvName = builtins.replaceStrings [ "/" ] [ "-" ] name;

      makeCSSArg =
        cssPath:
        let
          res = if builtins.isPath cssPath then siteUrl + (removeCurrentDirPrefix cssPath) else cssPath;
        in
        lib.escapeShellArg "--css=${res}";

      cssArgs = lib.concatStringsSep " " (map makeCSSArg css);

    in
    runCommand drvName { } ''
      target=$out/${lib.escapeShellArg name}
      mkdir -p "$(dirname "$target")"
      echo "$target"
      echo "$file"
      ${lib.getExe pandoc} --standalone \
                           --template=${template} \
                           --to=html5 \
                           --output="$target" \
                           ${cssArgs} \
                           --variable=include-before:${lib.escapeShellArg include_before} \
                           ${file} \
                           --verbose
    '';

  homePage = page ./README.md;
  index = stdenv.mkDerivation {
    name = "index.html";
    buildInputs = [ homePage ];
    buildCommand = ''
      mkdir -p $out
      ln -s "${homePage}"/README.html $out/index.html
    '';
  };

in
symlinkJoin {
  name = "www_root";
  paths = [
    homePage
    index
    #(page ./README.md)
    (page ./pages/about.md)
    (addFile ./dir/nix_hacking_1.png)
    (addFile ./you_are_here.png)
  ] ++ map (p: addFile p) (builtins.filter (x: builtins.isPath x) css);
}
