# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/cli">cli</a>::Command</code> (Struct)

How `sn` commands are declared. A command is a value: its options, positionals and help all come
from one `Command`, so the parser and `--help` can't disagree. See
[Adding a command](../namespaces/cli.md#adding-a-command).

`#include <sonata/cli/command.hpp>`

## Definition

```cpp
enum class Group { Project, Tools };

struct Command {
    std::string name;
    std::string summary;     // one line, for lists
    std::string description; // optional longer text for --help
    Group group = Group::Project;
    std::vector<Positional> positionals;
    std::vector<Option> options;
    std::vector<std::string> examples;
    bool takesRest = false; // documents and allows "-- <args>..."
    std::vector<Command> subcommands;

    std::function<int(Context&)> run;
};
```

## Members

| Member | Description |
|---|---|
| `name` | What's typed after `sn` (or after the parent command), like `init` in `sn init`. |
| `summary` | One line, shown in `sn --help` and at the top of the command's own help. |
| `description` | Optional longer text for `--help`. |
| `group` | The heading it's listed under in `sn --help`. |
| `positionals` | Its [positional arguments](#positional). |
| `options` | Its [options](#option). `--help` is added for you. |
| `examples` | Lines shown under **Examples**, each prefixed with `$`. |
| `takesRest` | Documents and allows `-- <args>...`, available as [`Args::rest()`](#args). |
| `subcommands` | Such as `add`, `remove`, `update` and `status` of `sn pkg`. They're listed under **Commands** in the parent's help. |
| `run` | The entry point. It returns the exit status. Throw [`UsageError`](#usageerror) for a bad command line and anything else for a failure; both are reported for you. |

## `Option`

```cpp
struct Option {
    std::string name;   // "output" is written --output
    char shortName = 0; // 'o' is written -o
    std::string value;  // shown as --output <file>; empty makes it a flag
    std::string description;
    std::vector<std::string> choices; // if not empty, the only accepted values
    bool repeatable = false;          // otherwise giving it twice is an error
};
```

## `Positional`

```cpp
struct Positional {
    std::string name;
    std::string description;
    bool required = false;
    bool variadic = false; // takes the rest; must come last
};
```

## `Args`

```cpp
class Args {
public:
    bool has(std::string_view option) const;
    std::optional<std::string> value(std::string_view option) const;
    const std::vector<std::string>& values(std::string_view option) const;

    std::optional<std::string> positional(std::string_view name) const;
    const std::vector<std::string>& positionals(std::string_view name) const;

    const std::vector<std::string>& rest() const;

    std::optional<int> integer(std::string_view option, int low, int high) const;
};
```

The parsed command line of one command.

| Method | Description |
|---|---|
| `has(option)` | Whether the option was given. |
| `value(option)`, `values(option)` | Its value, or every value of a `repeatable` option. |
| `positional(name)`, `positionals(name)` | A positional, or every value of a `variadic` one. |
| `rest()` | Everything after a bare `--`. |
| `integer(option, low, high)` | An integer option limited to `[low, high]`. A `UsageError` otherwise. |

## `Context`

```cpp
struct Context {
    const Args& args;
};
```

## `UsageError`

```cpp
class UsageError : public std::runtime_error {
public:
    explicit UsageError(const std::string& message, std::string hint = {});

    std::string hint;
};
```

A mistake on the command line: printed with its hint, with exit status 2.

## Example

```cpp
Command runCommand() {
    return {
        .name = "run",
        .summary = "Run a project without compiling it",
        .group = Group::Project,
        .positionals = {{.name = "path", .description = "The project, or a file inside it (default: this folder)"}},
        .options =
            {
                {.name = "entry", .shortName = 'e', .value = "file", .description = "Run <file> instead of the entrypoint"},
                {.name = "verbose", .shortName = 'v', .description = "Show the project, entry and libraries in use"},
            },
        .examples = {"sn run", "sn run ./my-app", "sn run -- --port 8080"},
        .takesRest = true,
        .run = run,
    };
}
```
