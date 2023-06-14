Build blag
```bash
nix-build -E "with import <nixpkgs> {}; callPackage ./blag.nix {}"
```
