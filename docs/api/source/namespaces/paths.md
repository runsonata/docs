# <code><a href="../sonata">sonata</a>::paths</code> (namespace)

Where Sonata keeps its files.

`#include <sonata/base/paths.hpp>`

```
$SONATA_HOME                          default ~/.sonata
├── bin/sn                            the installed executable
└── runtimes/<version>/<target>/sn    runtimes for `sn build --target` (sn.exe on Windows)
```

## `home`

```cpp
std::optional<std::filesystem::path> home();
```

`$SONATA_HOME`, or `~/.sonata`. `std::nullopt` if neither can be worked out.

## `runtimesDirectory`

```cpp
std::optional<std::filesystem::path> runtimesDirectory();
```

The folder runtimes for `sn build --target` live in, for this version.
