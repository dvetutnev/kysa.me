# First header

## Second header

* list 1
* list 2

Text

*italic*

**BBBBBB**

Русский

![PIC](dir/nix_hacking_1.png)

![PIC2](you_are_here.png)


# Run tests

```
nix eval --impure --expr 'import ./test.nix {}'
```

```
nix-build -A tests.fetchurl
```