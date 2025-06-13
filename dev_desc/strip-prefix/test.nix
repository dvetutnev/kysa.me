{
  pkgs ? import <nixpkgs> { },
}:
let
  runTests = pkgs.lib.runTests;
  stripPrefix = pkgs.callPackage ./. { };
in
runTests {
  test1 = {
    expr = stripPrefix {
      path = ./content/dir/file.md;
      prefix = ./content;
    };
    expected = "dir/file.md";
  };

  test2 = {
    expr = stripPrefix {
      path = ./content/folder/nested/image.svg;
      prefix = ./content/folder;
    };
    expected = "nested/image.svg";
  };
}
