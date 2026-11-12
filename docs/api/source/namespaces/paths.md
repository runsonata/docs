# <code><a href="../sonata">sonata</a>::paths</code> (namespace)

Where Sonata keeps its files.

`#include <sonata/base/paths.hpp>`

```
$SONATA_HOME                                     default ~/.sonata
├── bin/sn                                       the installed executable
└── runtimes/<version>/<target>/sn               the runtime with every feature (sn.exe on Windows)
                                /<features>/sn   one with only those, like tls+zstd/sn or none/sn
```

The runtimes of a target come in its `sonata-<target>-runtimes` release archive, laid out to be
extracted into `runtimes/<version>/<target>/`. See [Runtimes](bundle.md#runtimes).

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
