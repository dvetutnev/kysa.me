blocks:
let
  func =
    with builtins;
    blocks: # /
    foldl' (
      acc: elem: # /
      if isAttrs elem && elem.t == "Image" then
        acc ++ [ elem ]
      else if isAttrs elem && hasAttr "c" elem && isList elem.c then
        acc ++ (func elem.c)
      else if isList elem then
        acc ++ (func elem)
      else
        acc
    ) [ ] blocks;
in
func blocks
