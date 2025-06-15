{
  callPackage,
  symlinkJoin,
}:

let
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
  sideBar = mkSideBar (import ./navigation.nix);

  mkPage = callPackage ./mk-page.nix { inherit stripPrefix; } {
    inherit cssLinks sideBar;
  };

  html = mkPage {
    path = ./content/test.md;
    prefix = ./content;
  };

in
symlinkJoin {
  name = "www_root";
  paths = [ html ] ++ cssDrvs;
}
