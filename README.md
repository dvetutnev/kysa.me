---
title: my title
author: I am Dmitriy Vetutnev
date: may 2025
---

# First header

## Second header

Text

![PIC](dir/nix_hacking_1.png)

![PIC2](you_are_here.png)


# Run tests

Для runTests

```
nix eval --impure --expr 'import ./test.nix {}'
```

Для тестов из pkgs.testers (testEqualContents)

```
nix build -L --impure --expr 'import ./test2.nix'
```

```cpp
int main() {
 return 0;
}
```

```plantuml
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response

Alice -> Bob: Another authentication Request
Alice <-- Bob: another authentication Response
```


[About](about.md)

