{
  runCommand,
  stdenv,
  writeTextDir,
  symlinkJoin,
  pandoc,
  callPackage,
  lib,
}:
siteUrl:

let

  removeCurrentDirPrefix = callPackage ./rm_cur_dir_prefix.nix { };
  addFile = callPackage ./add_file.nix { inherit removeCurrentDirPrefix; };
  mkSideBar = callPackage ./mk_side_bar.nix { };

  sideBar = mkSideBar siteUrl;

  cssList = [
    ./css/poole.css
    ./css/syntax.css
    ./css/hyde.css
    ./css/hyde-styx.css
    "https://fonts.googleapis.com/css?family=PT+Sans:400,400italic,700|Abril+Fatface"
  ];

  mkCmdArg =
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

  cssArgs = lib.concatStringsSep " " (map mkCmdArg cssList);

  mkPage =
    callPackage ./mk_page.nix
      {
        inherit
          removeCurrentDirPrefix
          ;
      }
      {
        cssArgs = cssArgs;
        inherit sideBar;
      };

  #homePage = mkPage ./README.md;
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
  #index = mkIndex homePage;

in
symlinkJoin {
  name = "www_root";
  paths =
    [
      #homePage
      #index
      (mkPage ./README.md)
      (mkPage ./pages/about.md)
      (addFile ./dir/nix_hacking_1.png)
      (addFile ./you_are_here.png)
    ]
    ++ map (p: addFile p) # /
      (builtins.filter (x: builtins.isPath x) cssList);
}
