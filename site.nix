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
  siteUrl' = if lib.strings.hasSuffix "/" siteUrl then siteUrl else "${siteUrl}/";

  removeCurrentDirPrefix = callPackage ./rm_cur_dir_prefix.nix { };
  addFile = callPackage ./add_file.nix { inherit removeCurrentDirPrefix; };
  mkSideBar = callPackage ./mk_side_bar.nix { };

  sideBar = mkSideBar siteUrl';

  css = [
    ./css/poole.css
    ./css/syntax.css
    ./css/hyde.css
    ./css/hyde-styx.css
    "https://fonts.googleapis.com/css?family=PT+Sans:400,400italic,700|Abril+Fatface"
  ];

  mkPage =
    callPackage ./mk_page.nix
      {
        inherit removeCurrentDirPrefix addFile;
      }
      {

        siteUrl = siteUrl';
        inherit css sideBar;
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
      #(addFile ./dir/nix_hacking_1.png)
      #(addFile (lib.traceVal ./you_are_here.png))
    ]
    ++ map (p: addFile p) # /
      (builtins.filter (x: builtins.isPath x) css);
}
