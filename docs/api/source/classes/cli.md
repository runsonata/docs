# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/cli">cli</a>::CLI</code> (Class)
<<<<<<< HEAD
=======

>>>>>>> 10875da (continue)
A barebones class representing the CLI command, `sn`.

!!! warning

    This class and/or its properties were meant to be used
    only once, while defining the `sn` command.
<<<<<<< HEAD
    
=======

>>>>>>> 10875da (continue)
    It is **not recommended** to create a new CLI object if
    there already is one, which might lead to conflict.

## Definition

```cpp
class CLI {
public:
    int run(int argc, char** argv);
};
```

<<<<<<< HEAD
## Methods

### `int run(int argc, char** argv)`
Runs the command, which loops through all the registered sub-commands
and executes the entry function for that subcommand.

Prints the root help message if no subcommand or argument is supplied.
=======
`cli/main.cpp` is all it takes to make `sn`:

```cpp
int main(int argc, char** argv) {
    sonata::cli::CLI cli;
    return cli.run(argc, argv);
}
```

## Methods

### `int run(int argc, char** argv)`

Runs the command line and returns the exit code.

1. With no arguments, or `-h`/`--help`, prints the list of commands and returns `0`.
2. With `-v`/`--version`, prints `sonata <version>` (or the full build details when followed by
   `--verbose`) and returns `0`.
3. Otherwise looks up the command named by `argv[1]`. An unknown command prints an error, a
   "did you mean" suggestion (edit distance under 3) and returns `1`.
4. Walks down the command's [`children`](cli_command.md#children) as long as the next
   arguments name subcommands (`sn pkg add ...` → `pkg` → `add`).
5. If `-h` or `--help` appears in the remaining arguments (before a bare `--`), prints the help
   of the deepest command found and returns `0`.
6. Calls the top-level command's [`execute`](cli_command.md#execute) with everything after the
   command's name. If the top-level command has none, the subcommand's `execute` is called with
   the arguments after the subcommand's name. If neither has one, prints help.

Commands receive `argc`/`argv` with their own name already removed. A top-level command with an
`execute` (like `pkg`) dispatches to its subcommands itself.

## Output

Help and errors are colored when written to a terminal. `NO_COLOR` disables colors,
`FORCE_COLOR` forces them, and `TERM=dumb` disables them. On Windows, virtual terminal
processing is enabled for the console.
>>>>>>> 10875da (continue)
