# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/cli">cli</a>::Argument</code> (Struct)

Describes one argument of a [`Command`](cli_command.md), for its help page.

`#include "command.hpp"` (in `cli/`)

## Definition

```cpp
struct Argument {
    std::string name;
    std::vector<std::string> aliases;
    std::string description;
};
```

## Members

### `name`

```cpp
std::string name;
```

The argument as shown in help. It may include a placeholder for its value, e.g.
`"--output <file>"`.

### `aliases`

```cpp
std::vector<std::string> aliases;
```

Other spellings, shown in parentheses after the name: `--output <file> (-o)`.

### `description`

```cpp
std::string description;
```

What the argument does.

## Notes

`Argument` only describes; it doesn't parse. Each command reads its own `argv`.

```cpp
static const cli::Argument entry_arg{
    .name = "--entry",
    .aliases = {"-e"},
    .description = "Run <file> (relative to the project root) instead of the manifest's entrypoint"
};
```

For `--help`, use [`sonata::cli::help_argument`](../namespaces/cli.md#help_argument) rather
than declaring your own.
