{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
testers.testEqualContents {
  assertion = "describe of test_";
  expected = writeText "expected" "text423";
  actual = writeText "actual" "text423";
}
