{
  callPackage,
  symlinkJoin,
}:

siteUrl:

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
in
symlinkJoin {
  name = "www_root";
  paths =
    [ ]
    ++ map (
      p:
      addFile {
        path = p;
        prefix = ./.;
      }
    ) (builtins.filter (x: builtins.isPath x) css);
}
