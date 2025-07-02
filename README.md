---
title: kysa.me
author: Dmitriy Vetutnev
date: may 2025
---

# Run tests

For `runTests`

```
nix eval --impure --expr 'import ./test.nix {}'
```

For `pkgs.testers` (`testEqualContents`)

```
nix build -L --impure --expr 'import ./test2.nix'
```

# Highlight

```cpp
int main() {
 return 0;
}
```

# PlantUML

```plantuml
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response

Alice -> Bob: Another authentication Request
Alice <-- Bob: another authentication Response
```
