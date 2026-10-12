# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/cli">cli</a>::Command</code> (Struct)

<<<<<<< HEAD
A struct that stores information about a command (inside a [CLI](cli.md) object, like `init` or `pkg`) which gets read by
the [CLI](cli.md) while running the command, or printing its help message.
=======
A struct that stores information about a command (inside a [CLI](cli.md) object, like `init` or
`pkg`) which gets read by the [CLI](cli.md) while running the command, or printing its help
message.

`#include "command.hpp"` (in `cli/`)
>>>>>>> 10875da (continue)

## Definition

```cpp
struct Command {
    std::string name;
    std::string description;
    std::vector<Argument> args;
    std::vector<std::string> usage;
    std::vector<std::string> examples;
    std::function<int(int argc, char** argv)> execute;
    std::vector<Command> children;
};
```

<<<<<<< HEAD
### Members

## `std::string name`
The command's name/subcommand.

This string is what is supplied after `sn`, like `sn init`.

## `std::string description`
A brief explanation of what the command does.

Used while printing the command's help message.

## `std::vector<Argument> args`
nigga
=======
## Members

### `name`

```cpp
std::string name;
```

The command's name: what is typed after `sn` (or after the parent command), like `init` in
`sn init`.

For subcommands, the name may carry usage text after a space, e.g. `"add [path] [deps]"`. Only
the first word is matched against the command line; the whole string is shown in the parent's
help.

### `description`

```cpp
std::string description;
```

A brief explanation of what the command does, shown in `sn --help` and at the top of the
command's own help.

### `args`

```cpp
std::vector<Argument> args;
```

The [arguments](cli_argument.md) listed under **Arguments** in the command's help. This list is
for display only: the command parses its own `argv`.

### `usage`

```cpp
std::vector<std::string> usage;
```

Lines shown under **Usage**, e.g. `"sn run [path] [options] [-- <args>...]"`.

### `examples`

```cpp
std::vector<std::string> examples;
```

Lines shown under **Examples**, each prefixed with `$`.

### `execute`

```cpp
std::function<int(int argc, char** argv)> execute;
```

The entry point. It receives the arguments after the command's name and returns the exit code
(`0` for success). Help flags never reach it: [`CLI::run`](cli.md#int-runint-argc-char-argv)
handles them first.

For a command with `children`, a top-level `execute` receives everything after the command's
name (including the subcommand name) and dispatches itself. If it is empty, the subcommand's own
`execute` is called instead.

### `children`

```cpp
std::vector<Command> children;
```

Subcommands, such as `add`, `remove`, `update` and `status` of `sn pkg`. They are listed under
**Commands** in the parent's help, and `sn pkg add --help` shows the child's own help.

## Example

```cpp
static const cli::Command command{
    .name = "run",
    .description = "Run a project without compiling it (aka live test)",
    .args = {cli::help_argument, entry_arg, verbose_arg},
    .usage = {"sn run [path] [options] [-- <args>...]"},
    .examples = {"sn run", "sn run ./my-project"},
    .execute = run,
    .children = {}
};
```
>>>>>>> 10875da (continue)
