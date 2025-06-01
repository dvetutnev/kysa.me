blocks:
let
  pkgs = import <nixpkgs> { };
  traceVal = pkgs.lib.traceVal;
  traceIf = pkgs.lib.traceIf;
  func =
    with builtins;
    blocks: # /
    foldl' (
      acc: elem': # /
      let
        elem = traceVal elem';
      in
      if (!isAttrs elem) then
        traceIf true "not attr" acc
      else if elem.t == "Image" then
        traceIf true "image" (acc ++ [ elem ])
      else if isList elem.c then
        traceIf true "list" (acc ++ (func elem.c))
      else
        traceIf true "else" acc
    ) [ ] (traceVal blocks);
in
func blocks
