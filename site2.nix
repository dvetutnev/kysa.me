{
  callPackage,
  symlinkJoin,
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

  mkSideBar = callPackage ./mk_side_bar.nix { };
  sideBar = mkSideBar siteUrl;

  mkPage = callPackage ./mk-page.nix { inherit stripPrefix addFile; } {
    inherit siteUrl css sideBar;
  };

in
symlinkJoin {
  name = "www_root";
  paths = [
    (mkPage {
      path = ./content/README.md;
      prefix = ./content;
    })
    (mkPage {
      path = ./content/pages/about.md;
      prefix = ./content;
    })
  ] ++ cssDrvs;
}
