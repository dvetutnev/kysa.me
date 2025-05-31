blocks:
let
  func =
    blocks: # /
    builtins.foldl' (
      acc: elem: # /
      if elem.t == "Image" then
        acc ++ [ elem ]
      else if builtins.isList elem.c then
        acc ++ (func elem.c)
      else
        acc
    ) [ ] blocks;
in
func blocks
