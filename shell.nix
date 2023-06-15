{ pkgs ? import <nixpkgs> {} }:

with pkgs; mkShell {
  name = "blag-shell";
  inputsFrom = [
    (callPackage ./default.nix {})
  ];
}

