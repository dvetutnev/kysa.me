{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
let
  testEqualContents = testers.testEqualContents;
  recurseIntoAttrs = lib.recurseIntoAttrs;

  contentPrefix = ./test_content;

  stripPrefix = callPackage ../strip-prefix { };
  addFile = callPackage ./. { inherit stripPrefix; };
in
recurseIntoAttrs {
  test1 =
    let
      file = lib.path.append contentPrefix "file.md";
    in
    testEqualContents {
      assertion = "addFile";
      expected = writeTextDir "file.md" (builtins.readFile file);
      actual = writeTextDir "file.md" ''42'';

    };

  test2 = testEqualContents {
    assertion = "addFile2";
    expected = writeTextDir "expected2" ''42'';
    actual = writeTextDir "expected2" ''42'';
  };
}
