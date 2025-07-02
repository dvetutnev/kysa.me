# Run tests

For `runTests`

```
nix eval --impure --expr 'import ./test.nix {}'
```

For `pkgs.testers` (`testEqualContents`)

```
nix build -L --impure --expr 'import ./test.nix'
```
