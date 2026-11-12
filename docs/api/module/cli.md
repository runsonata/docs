# @sonata/cli

Command-line arguments for programs. You declare the options, arguments and subcommands once,
and parsing, `--help` and the error messages all come from that declaration, so they can't
disagree.

```luau
local cli = require("@sonata/cli")

local options = cli.parse({
    description = "Greets people.",
    version = "1.0.0",
    arguments = {
        { name = "who", description = "Who to greet", default = "world" },
    },
    options = {
        { name = "loud", short = "l", description = "Shout" },
        { name = "times", short = "n", type = "integer", default = 1, description = "How many times" },
    },
})

for _ = 1, options.times do
    local line = "hello, " .. options.who
    print(if options.loud then string.upper(line) else line)
end
```

```console
$ greet -l -n 2 Ada
HELLO, ADA
HELLO, ADA
$ greet --help
greet 1.0.0
Greets people.

Usage: greet [options] [who]

Arguments:
  <who>  Who to greet (default: world)

Options:
  -l, --loud             Shout
  -n, --times <integer>  How many times (default: 1)
  -h, --help             Show this help
      --version          Show the version
$ greet --tims 2
error: unknown option '--tims' (did you mean --times?)
Run 'greet --help' for usage.
```

Without a `name` in the spec, the program is called by its executable's name in a built program,
and by the project's under `sn run`.

## The result

Each option and argument is in the result under its name in camelCase: `--dry-run` is
`options.dryRun`. Every declared option has a value there, its default if it wasn't given:

| Option | Not given | Given |
|---|---|---|
| A flag | `false`, or its `default` | `true` (`false` with `--no-name`) |
| A repeatable flag | `0` | how many times, as in `-vvv` |
| With a value | `nil`, or its `default` | the value, a string or a number by its `type` |
| Repeatable, with a value | `{}`, or its `default` | a list of the values |

An argument that wasn't given is `nil`, or its `default`; a variadic one is a list. With
subcommands, `command` is the one chosen, like `"remote add"`.

Two names that would have the same key, like `dry-run` and `dryRun`, are a mistake in the
spec.

## Writing options

Options can be written every way people write them:

| Written | Means |
|---|---|
| `--times 3`, `--times=3` | A long option and its value. |
| `-n 3`, `-n3`, `-n=3` | A short option and its value. |
| `-ln 3` | Flags grouped together; the last one may take a value. |
| `--no-fancy` | Turns off a flag. Every flag that isn't repeatable accepts it; help shows `--[no-]fancy` for those that default to `true`. |
| `--` | Everything after it is an argument, even if it starts with `-`. |
| `-5`, `-` | Arguments: a negative number (unless a short option is a digit), and a lone `-`. |

Options can come before, between and after the arguments. A non-repeatable option given twice
is a mistake.

## The spec

```luau
cli.parse({
    name = "tool",              -- optional
    version = "1.0.0",          -- optional: adds --version
    description = "What it does.",
    options = { ... },
    arguments = { ... },        -- or commands, not both
    commands = { ... },
    examples = { "tool --verbose build" },
})
```

`--help` (and `-h`, unless an option takes it) is added to every command, and `--version` to the
program when it has a `version`. A field the library doesn't know is a mistake, with a suggestion
if it looks like a typo.

### Options

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Written `--name`: letters, digits and `-`. `help` and `version` are taken. |
| `short` | `string?` | One letter or digit, written `-x`. |
| `description` | `string?` | Shown in help. |
| `value` | `string?` | The placeholder in help, like `"file"` for `--output <file>`. |
| `type` | `string?` | `"string"`, `"number"` or `"integer"`. |
| `default` | `any?` | Used when the option isn't given. A list for a repeatable option. |
| `required` | `boolean?` | It must be given. Not for flags, or with a `default`. |
| `repeatable` | `boolean?` | It may be given more than once. |
| `choices` | `{ any }?` | The only values accepted. |
| `env` | `string?` | An environment variable read when the option isn't given. |

An option with a `value` or a `type` takes a value; one with neither is a flag. An option's
`default` and `choices` must be of its type, and the default one of the choices.

With `env`, the variable stands in for the option when it isn't on the command line. An empty
variable counts as unset, and a flag's must be `1`, `0`, `true`, `false`, `yes`, `no`, `on` or
`off`. A required option is satisfied by its variable.

```luau
{ name = "port", short = "p", type = "integer", default = 8080, env = "PORT" }
{ name = "format", value = "kind", choices = { "json", "text" }, default = "text" }
{ name = "include", short = "I", value = "dir", repeatable = true }
{ name = "verbose", short = "v", repeatable = true }   -- -vv is 2
```

### Arguments

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Letters, digits, `-` and `_`. Shown as `<name>`. |
| `description` | `string?` | Shown in help. |
| `type` | `string?` | `"string"` (the default), `"number"` or `"integer"`. |
| `default` | `any?` | Used when it isn't given. A list for a variadic argument. |
| `required` | `boolean?` | Whether it must be given. Default: `true`, unless it has a `default` or is variadic. |
| `variadic` | `boolean?` | Takes the rest of the arguments, as a list. Only the last one can be. |
| `choices` | `{ any }?` | The only values accepted. |

A required argument can't follow an optional one. Arguments left over at the end are a mistake.

### Commands

```luau
local options = cli.parse({
    name = "notes",
    options = { { name = "quiet", short = "q" } },
    commands = {
        {
            name = "add",
            description = "Add a note",
            arguments = { { name = "text" } },
            options = { { name = "tag", short = "t", value = "name", repeatable = true } },
        },
        {
            name = "list",
            description = "List the notes",
            options = { { name = "limit", type = "integer", default = 20 } },
        },
    },
})

if options.command == "add" then
    print("adding", options.text, #options.tag)
elseif options.command == "list" then
    print("listing", options.limit)
end
```

A command takes the same fields as the spec, except `version`, and its `name` is the word that
chooses it. Commands can have commands of their own, as in `git remote add`. When a program or a
command has commands, one must be given.

The options of a command can be given after it; the options of the commands above it, before or
after. A command's options aren't in the result unless it was chosen.

## Mistakes

A mistake in the spec is the programmer's: the library raises at once, pointing at the line that
called it, whatever the command line says.

A mistake on the command line is the user's. `cli.parse` prints it to stderr with a pointer to
`--help`, and exits with status 2, the status for a bad command line. Each message says what's
wrong and, for a typo in an option or command, what was probably meant.

## cli.parse

```luau
cli.parse(spec: Spec, argv: { string }?): Result
```

Parses the program's arguments (the [`args`](globals.md) global), or `argv`. On `--help` or
`--version` it prints them to stdout and exits with status 0. On a mistake it prints it to stderr
and exits with status 2.

## cli.tryParse

```luau
cli.tryParse(spec: Spec, argv: { string }?): (Result?, string?, number?)
```

Like `cli.parse`, but returns instead of printing and exiting: the result, or `nil`, a message
and the exit status that fits. Status 0 means `--help` or `--version` was asked for, and the
message is the text to print; status 2 means a mistake on the command line.

```luau
local options, message, status = cli.tryParse(spec, { "--colr", "red" })
--> nil, "unknown option '--colr' (did you mean --color?)", 2
```

## cli.help

```luau
cli.help(spec: Spec, command: string?): string
```

The help text `--help` prints, for the program or for a command like `"remote add"`. Descriptions
are wrapped to 80 columns, and line breaks in them are kept.
