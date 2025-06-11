{
  callPackage,
  symlinkJoin,
  stdenv,
  lib,
}:

siteUrl':

let
  siteUrl = if lib.strings.hasSuffix "/" siteUrl' then siteUrl' else "${siteUrl'}/";

  stripPrefix = callPackage ./strip-prefix { };
  addFile = callPackage ./add-file { inherit stripPrefix; };

  css = [
    ./css/poole.css
    ./css/syntax.css
    ./css/hyde.css
    ./css/hyde-styx.css
    "https://fonts.googleapis.com/css?family=PT+Sans:400,400italic,700|Abril+Fatface"
  ];

  cssDrvs = map (
    p:
    addFile {
      path = p;
      prefix = ./.;
    }
  ) (builtins.filter (x: builtins.isPath x) css);

  cssLinks = map (
    x:
    if builtins.isPath x then
      stripPrefix {
        path = x;
        prefix = ./.;
      }
    else
      x
  ) css;

  mkSideBar = callPackage ./mk-sidebar.nix { };
  sideBar = mkSideBar siteUrl;

  mkPage = callPackage ./mk-page.nix { inherit stripPrefix addFile; } {
    inherit siteUrl cssLinks sideBar;
  };

  contentPrefix = ./content;

  mdDrvs =
    let
      hasSuffix = suffix: path: lib.strings.hasSuffix suffix (builtins.toString path);
      mdFiles = builtins.filter (x: (hasSuffix ".md" x)) (lib.fileset.toList contentPrefix);
    in
    map (
      x:
      mkPage {
        path = x;
        prefix = contentPrefix;
      }
    ) mdFiles;

  homeDrv =
    let
      pred = x: lib.strings.hasSuffix "home.html" x.name;
      home = lib.lists.findFirst pred null mdDrvs;
    in
    lib.throwIf (isNull home) "Can`t find home page in HTML derivations" home;

  indexDrv = stdenv.mkDerivation {
    name = "index.html";
    buildInputs = [ homeDrv ];
    allowSubstitutes = false;
    buildCommand = ''
      mkdir -p $out
      ln -s "${homeDrv}/${homeDrv.name}" $out/index.html
    '';
  };

in
symlinkJoin {
  name = "www_root";
  paths = mdDrvs ++ cssDrvs ++ [ indexDrv ];
}
