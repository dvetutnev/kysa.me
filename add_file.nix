{ stdenv, removeCurrentDirPrefix }:

file:
stdenv.mkDerivation rec {
  destName = removeCurrentDirPrefix file;
  name = builtins.replaceStrings [ "/" ] [ "-" ] destName;
  buildCommand = ''
    install -m 644 -D ${file} $out/${destName}
  '';
}
