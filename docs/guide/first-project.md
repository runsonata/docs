# Your first project

This page creates a project, runs it, passes it arguments and builds it into an executable.

## Creating a project

```console
$ sn init hello
✓ Created hello

Next
  cd hello
  sn run     run it
  sn build   compile it to dist/
$ cd hello
```

`sn init [path]` creates the folder if it doesn't exist (the current directory if no path is
given) and fills it with:

```
hello/
├── main.luau            the entry script
├── .gitignore           keeps .sonata/deps/ and dist/ out of git
└── .sonata/
    └── project.luau     the manifest
```

If the folder already has a `main.luau` or a `.gitignore`, they're left as they are.

`main.luau` contains `print("Hello from Sonata!")`, and `.sonata/project.luau` holds the manifest:

```luau
return {
    name = "hello",
    version = "0.1.0",
    entrypoint = "main.luau",
}
```

The name comes from the folder. Use `--name` to give the project a different one:

```sh
sn init hello --name weather
```

You can edit the manifest by hand: it must stay a single `return { ... }` of literal values (see
[The project manifest](manifest.md)).

`sn init` won't replace an existing project's manifest unless you add `--force`, which writes a
new one and leaves your code alone. To set up your editor as well, add `--lsp`, in a new project
or one you already have: see [Editor support](editors.md).

To check that a folder is a valid project, run [`sn doctor`](doctor.md) from inside it. Along with
your installation, it checks the manifest, the entrypoint and that your code compiles.

## Running it

```console
$ sn run
Hello from Sonata!
```

`sn run [path]` finds the project that contains `path` (the current directory by default,
searching parent folders too), and runs its entry script. Nothing is compiled to disk; this
is the quick way to try changes.

Some useful options:

```sh
sn run ./hello                      # run a project from elsewhere
sn run --entry tools/seed.luau      # run another script of the project
sn run --verbose                    # print the project, entry and libraries in use
sn run --install                    # fetch missing dependencies first
```

## Passing arguments

Everything after `--` goes to the script. It is available as the global `args`, an array of
strings:

```luau
-- main.luau
print(`got {#args} arguments`)
for i, arg in args do
    print(i, arg)
end
```

```console
$ sn run -- --port 8080
got 2 arguments
1   --port
2   8080
```

The same list is available as [`process.args`](../api/module/process.md).

## Using a built-in library

Sonata's libraries are imported with `require("@sonata/<name>")`. They need no installation:

```luau
local fs = require("@sonata/fs")
local json = require("@sonata/json")

local config = { name = "hello", debug = true }
fs.writeFile("config.json", json.encode(config, { indent = 2 }))

local loaded = json.decode(fs.readFile("config.json"))
print(loaded.name) --> hello
```

See the [module API reference](../api/module/index.md) for every library.

## Splitting code into modules

Create `src/greet.luau`:

```luau
local greet = {}

function greet.hello(name: string): string
    return `Hello, {name}!`
end

return greet
```

And require it from `main.luau` with a path relative to `main.luau`:

```luau
local greet = require("./src/greet")
print(greet.hello("Sonata"))
```

[Modules and require](modules.md) covers the rules in detail.

## Building an executable

```console
$ sn build
Building hello 0.1.0 for linux-x64
  ✓ Selected libraries all
  ✓ Compiled 2 modules
  ✓ Wrote the executable from this sn 11 ms
✓ Built dist/hello (3.8 MiB)
$ ./dist/hello
Hello, Sonata!
```

`sn build` compiles the project and its dependencies into a single executable in `dist/`. It
runs on machines without Sonata installed. See [Building executables](building.md) to choose
the output path, shrink the program and pack asset files into it.

## Errors

If a script raises an error that nothing catches, `sn run` (and a built program) prints the
message and a stack trace and exits with status 1:

```console
$ sn run
/home/me/hello/main.luau:3: attempt to index nil with 'name'
stacktrace:
...
```

Errors in other [tasks](tasks.md) are reported but don't stop the program; only an error in the
entry script ends it.
