{
  pkgs ? import <nixpkgs> { },
}:

let
  runTests = pkgs.lib.runTests;
  extractImagePaths = pkgs.callPackage ./. { };
in
runTests {
  testExtractImagePaths = {
    expr = extractImagePaths ./test.md;
    expected = [
      "dir/picture.png"
      "image.svg"
    ];
  };
}
