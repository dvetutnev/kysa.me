{
  pkgs ? import <nixpkgs> { },
}:

let
  runTests = pkgs.lib.runTests;
  traceVal = pkgs.lib.traceVal;
in
runTests {
  test2 =
    let
      blocks = [
        {
          t = "Image";
          c = "pic1.jpg";
        }
        {
          t = "Block";
          c = [
            {
              t = "Image";
              c = "pic2.jpg";
            }
            {
              t = "Header";
              c = "tEEExt";
            }
            {
              t = "Image";
              c = "pic3.jpg";
            }
            {
              t = "Block";
              c = [
                {
                  t = "Text";
                  c = "text";
                }
                {
                  t = "Image";
                  c = "pic4.jpg";
                }
              ];
            }
          ];
        }
      ];

      func =
        with builtins;
        blocks: # /
        foldl' (
          acc: elem: # /
          if elem.t == "Image" then
            [ elem ] ++ acc
          else if isList elem.c then
            (func elem.c) ++ acc
          else
            acc
        ) [ ] blocks;

      collectImages = blocks: pkgs.lib.reverseList (func blocks);

    in
    {
      expr = collectImages blocks;
      expected = [
        {
          t = "Image";
          c = "pic1.jpg";
        }
        {
          t = "Image";
          c = "pic2.jpg";
        }
        {
          t = "Image";
          c = "pic3.jpg";
        }
        {
          t = "Image";
          c = "pic4.jpg";
        }
      ];
    };
}
