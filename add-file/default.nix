{
  stdenv,
  lib,
  stripPrefix,
}:

{ path, prefix }:
stdenv.mkDerivation rec {
  destName = stripPrefix { inherit path prefix; };
  name = lib.strings.replaceStrings [ "/" ] [ "-" ] destName;
  buildCommand = ''
    install -m 644 -D ${path} $out/${destName}
  '';
  preferLocalBuild = true;
  allowSubstituties = false;
}
