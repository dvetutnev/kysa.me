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

  removeCurrentDirPrefix = import ./rm_cur_dir_prefix.nix { inherit lib; };
  addFile = import ./add_file.nix { inherit stdenv removeCurrentDirPrefix; };
  mkSideBar = import ./mk_side_bar.nix { inherit lib; };

  mkHTML =
    file:
    let
      template = ./default.html5;

      include_before = mkSideBar siteUrl;

      name = builtins.replaceStrings [ ".md" ] [ ".html" ] (removeCurrentDirPrefix file);

      drvName = builtins.replaceStrings [ "/" ] [ "-" ] name;

      mkCSSArg =
        cssPath:
        let
          res =
            if
              builtins.isPath cssPath # \
            then
              siteUrl + (removeCurrentDirPrefix cssPath)
            else
              cssPath;
        in
        lib.escapeShellArg "--css=${res}";

      cssArgs = lib.concatStringsSep " " (map mkCSSArg css);

    in
    runCommand drvName
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        target=$out/${lib.escapeShellArg name}
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

  homePage = mkHTML ./README.md;
  mkIndex =
    homePage:
    stdenv.mkDerivation {
      name = "index.html";
      buildInputs = [ homePage ];
      preferLocalBuild = true;
      allowSubstitutes = false;
      buildCommand = ''
        mkdir -p $out
        ln -s "${homePage}/${homePage.name}" $out/index.html
      '';
    };
  index = mkIndex homePage;

in
symlinkJoin {
  name = "www_root";
  paths = [
    homePage
    index
    #(page ./README.md)
    (mkHTML ./pages/about.md)
    (addFile ./dir/nix_hacking_1.png)
    (addFile ./you_are_here.png)
  ] ++ map (p: addFile p) (builtins.filter (x: builtins.isPath x) css);
}
