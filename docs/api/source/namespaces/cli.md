# <code><a href="../sonata">sonata</a>::cli</code> (namespace)

The `sn` command line. It lives in `source/cli/sonata/cli/` and links on top of the core; nothing
in the core or the libraries may depend on it.

```
app.hpp          run(): the whole command line
command.hpp      how commands are declared
ui/console.hpp   all output: colors, symbols, sections, warnings
commands/        one file per command, in sonata::cli::commands
doctor/          sn doctor, in sonata::doctor
lsp/             the files sn init --lsp writes, in sonata::cli::lsp
```

## Classes & Structs

| Class | Description |
|---|---|
| [`Command`](../classes/cli_command.md) | A command or subcommand, e.g. `init` or `pkg add`. |
| [`Option`](../classes/cli_command.md#option) | An option of a command, like `--output`. |
| [`Positional`](../classes/cli_command.md#positional) | A positional argument of a command. |
| [`Args`](../classes/cli_command.md#args) | The parsed command line of one command. |
| [`Context`](../classes/cli_command.md#context) | What a command receives when it runs. |
| [`UsageError`](../classes/cli_command.md#usageerror) | A mistake on the command line. |

## Functions

### `run`

```cpp
int run(int argc, char** argv);
```

`#include <sonata/cli/app.hpp>`

The `sn` command line. Returns the process exit status. `main()` calls it after
[`runtime::runIfBundled`](runtime.md#runifbundled) finds no bundle.

### `parseArguments`

```cpp
Args parseArguments(const Command& command, const std::vector<std::string>& arguments);
```

Parses what follows the command's name. Throws [`UsageError`](../classes/cli_command.md#usageerror).

### `printCommandHelp`

```cpp
void printCommandHelp(const Command& command, const std::string& path);
```

`sn <path> --help`. `path` is how the command was reached: `"sn pkg add"`.

## Adding a command

A command is a value: its options, positionals and help all come from one
[`Command`](../classes/cli_command.md), so the parser and `--help` can't disagree. Commands never
look at `argv`.

1. Copy `commands/_template.cpp.txt` to `commands/<name>.cpp`. CMake picks it up by itself.
2. Add `SONATA_COMMAND(<name>)` to `commands.def`, whose order is the order in `sn --help`.

```cpp
#include <iostream>

#include <sonata/cli/commands/commands.hpp>
#include <sonata/cli/ui/console.hpp>

namespace sonata::cli::commands {

namespace {

int greet(Context& context) {
    const std::string name = context.args.positional("name").value_or("world");
    const int times = context.args.integer("times", 1, 10).value_or(1);

    for (int i = 0; i < times; ++i) {
        std::cout << ui::accent("Hello") << ", " << name << "!\n";
    }
    return 0;
}

} // namespace

Command greetCommand() {
    return {
        .name = "greet",
        .summary = "Say hello",
        .group = Group::Tools,
        .positionals = {{.name = "name", .description = "Who to greet (default: world)"}},
        .options = {{.name = "times", .shortName = 'n', .value = "count", .description = "How many times, 1 to 10"}},
        .examples = {"sn greet", "sn greet Ada -n 3"},
        .run = greet,
    };
}

} // namespace sonata::cli::commands
```

The command now appears in `sn --help`, gets `sn greet --help`, and takes part in "did you mean"
suggestions.

A few rules hold for every command:

- Results go to stdout and everything else to stderr, through `ui::`. Don't write escape codes or
  symbols by hand: `ui::` handles `NO_COLOR`, pipes and ASCII terminals.
- The exit status is `0` for success, `1` for failure and `2` for a bad command line. Throw
  `UsageError` for the last one and anything else for a failure; both are reported for you.
- Errors say what to do next, and typos get a suggestion ([`text::closestMatch`](text.md)).
