{ stdenv, stripPrefix }:

{ path, prefix }:
stdenv.mkDerivation rec {
  destName = stripPrefix { inherit path prefix };
  name = replaceStrings [ "/" ] [ "-" ] destName;
  buildCommand = ''
    install -m 644 -D ${file} $out/${destName}
  '';
  preferLocalBuild = true;
  allowSubstituties = false;
}
