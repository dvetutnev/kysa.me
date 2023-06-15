{ stdenv
, pkgs
}:

with pkgs; let
  blag = callPackage ./blag.nix {};
in
  stdenv.mkDerivation {
    name = "kysa.me";
    src = ./.;
    nativeBuildInputs = [ blag ];
  }
