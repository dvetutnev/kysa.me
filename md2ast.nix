{
  callPackage,
}:

file:
let
  md2json = callPackage ./md2json.nix { };
  json = md2json file;
  ast = with builtins; fromJSON (readFile json);
in
ast
