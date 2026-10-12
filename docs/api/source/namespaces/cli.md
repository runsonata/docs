# <code><a href="../sonata">sonata</a>::cli</code> (namespace)

The `sonata::cli` namespace contains the classes behind the `sn` command. They live in the
`cli/` folder of the source tree (`cli/cli.hpp`, `cli/command.hpp`) and are part of the `sn`
executable, not of the installed library.

The commands themselves (`init`, `pkg`, `run`, `build`) are in `cli/commands/`, in the
`sonata::commands` namespace.

## Classes & Structs

| Class | Description |
|---|---|
| [`CLI`](../classes/cli.md) | The `sn` command: dispatches to commands and prints help. |
| [`Command`](../classes/cli_command.md) | A command or subcommand, e.g. `init` or `pkg add`. |
| [`Argument`](../classes/cli_argument.md) | An argument of a [`Command`](../classes/cli_command.md), like `--help`, shown in its help. |

## `help_argument`

```cpp
inline const Argument help_argument{
    .name = "--help",
    .aliases = {"-h"},
    .description = "Shows help information about the command or subcommand"
};
```

`-h` and `--help` are handled by [`CLI`](../classes/cli.md) for every command, so a command
never has to look for them itself. If a command doesn't list a help argument, its help page
gets a `--help, -h  Show this help` row automatically. The top-level commands list
`sonata::cli::help_argument` explicitly so it appears first; don't declare your own `--help`
argument.

## Adding a command

`cli/commands/example.cpp` is a template. A command is a function plus a `Command` describing
it:

```cpp
// cli/commands/hello.hpp
#pragma once
#include "command.hpp"

namespace sonata::commands {
const cli::Command& hello_command();
int hello(int argc, char** argv);
}
```

```cpp
// cli/commands/hello.cpp
#include <iostream>
#include <string>

#include "commands/hello.hpp"

namespace sonata::commands {

// argv holds the arguments after the command's own name.
int hello(int argc, char** argv) {
    const std::string name = argc > 0 ? argv[0] : "world";
    std::cout << "Hello, " << name << "!\n";
    return 0;
}

const cli::Command& hello_command() {
    static const cli::Command command{
        .name = "hello",
        .description = "Say hello",
        .args = {cli::help_argument},
        .usage = {"sn hello [name]"},
        .examples = {"sn hello", "sn hello Ada"},
        .execute = hello,
        .children = {},
    };
    return command;
}

} // namespace sonata::commands
```

Then:

1. add `commands/hello.cpp` to the `sonata_cli` sources in `cli/CMakeLists.txt`;
2. include `commands/hello.hpp` in `cli/cli.cpp` and add `commands::hello_command()` to the
   list returned by `commands()`.

The command now appears in `sn --help`, gets `sn hello --help`, and takes part in "did you
mean" suggestions. Return `0` on success and `1` on failure, and print errors to `stderr` as
`error: <message>`.
