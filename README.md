Build blag

```bash
nix-build -E "with import <nixpkgs> {}; callPackage ./blag.nix {}"
```

Shell with blag

```bash
nix-shell -E "with import <nixpkgs> {}; callPackage ./default.nix {}"
```

