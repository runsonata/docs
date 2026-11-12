# Building executables

`sn build` turns a project into a single executable that runs without Sonata installed.

```console
$ sn build
Building weather 1.2.0 for linux-x64
  ✓ Selected libraries all
  ✓ Compiled 12 modules
  ✓ Wrote the executable from this sn 9 ms
✓ Built dist/weather (3.8 MiB)
```

## What happens

1. **Settings.** The [`build` table](manifest.md#build) of the manifest is read, and command-line
   options override it for this build.
2. **Libraries.** The built-in libraries the program may use are worked out from
   `build.libraries` of the project and of every installed dependency.
3. **Compile.** Every `.luau` file of the project and of each dependency is compiled to
   bytecode, except [test files](testing.md) (`*.test.luau`). Every literal `require("@sonata/x")` is checked against the selected libraries.
   All compile errors and unselected libraries are reported together.
4. **Assets.** The files listed in `build.assets` of every package are collected. They are
   copied into the executable a piece at a time when it's written, so no size limit applies.
5. **Runtime.** The `sn` executable to start from is picked (see [Runtimes](#runtimes)). Nothing
   is compiled: this step only finds a file.
6. **Write.** The compiled program is appended to the runtime, producing one executable.

The built program behaves exactly like `sn run`: same module system, same globals, same
libraries. Inside it, [`sonata.bundled`](../api/module/globals.md) is `true` and
`sonata.project.root` is the folder that holds the executable.

## Options

| Option | Manifest field | Description |
|---|---|---|
| `--output <file>`, `-o` | `build.output` | Where to write the program. Default: `dist/<name>`. On the command line the path is relative to the current directory; in the manifest, to the project root. `.exe` is added on Windows. |
| `--libs <a,b,...>`, `-l` | `build.libraries` | The built-in libraries the program may use, replacing the root manifest's list. |
| `--all-libs` | | Allow every built-in library, whatever the manifests say. Can't be combined with `--libs`. |
| `--without <a,b,...>` | `build.without` | Optional features to leave out, replacing the manifest's list. See [Leaving features out](#leaving-features-out). |
| `--optimize <0-2>`, `-O` | `build.optimize` | Luau optimization level (default `1`). |
| `--debug-level <0-2>`, `-g` | `build.debug` | Luau debug info: `0` none, `1` line numbers (default), `2` full. |
| `--no-compress` / `--compress` | `build.compress` | Don't compress the packed program / do (the default). |
| `--strict` | `--!strict` | Treat the project as `--!strict` for this build. |
| `--entry <file>`, `-e` | `entrypoint` | Start at another `.luau` file of the project. |
| `--target <platform>`, `-t` | | Build for another platform, like `linux-x64`. See [Runtimes](#runtimes). |
| `--runtime <file>` | | Use this `sn` executable as the runtime. |
| `--install`, `-i` | | Fetch missing dependencies first. |

Options take their value either as `--output dist/app` or `--output=dist/app`.

```sh
sn build -o bin/app
sn build --libs fs,path,term
sn build -t windows-x64 -O 2 -g 0
```

## Choosing libraries

By default a program may use every built-in library. Declaring the ones you use catches mistakes
early:

```luau
build = {
    libraries = { "fs", "path", "term" },
},
```

With this list:

- `sn run` refuses `require("@sonata/net")` with
  `built-in library '@sonata/net' is not enabled for this program (add it to build.libraries in ...)`.
- `sn build` reports every file and line that requires an unlisted library.
- A built program refuses the others in the same way, even through a computed require.

The list decides what a program may use. It also decides which optional features the program
needs, and so which [runtime](#leaving-features-out) carries it: leave out every library that
uses SQLite, and the program can be built without SQLite in it.

Only literal requires (`require("@sonata/fs")`) are checked at build time. A computed require
still fails at runtime if the library isn't selected.

The [manifest page](manifest.md#buildlibraries) explains how dependencies' lists combine, and
[`--!strict`](manifest.md#strict) makes the lists mandatory.

## Runtimes

The runtime is the part of the executable that runs your program. Sonata has no separate runtime:
`sn` is one. A built program is a copy of the `sn` executable with your compiled program attached,
and when it starts, it finds your program and runs that instead of the command line.

This means `sn build`:

- needs no compiler, CMake or source code;
- takes milliseconds, whatever libraries you use;
- makes programs with no dependencies, because `sn` has none. There's no separate standalone
  mode: every program is standalone.

`sn build` picks the file to start from like this:

1. With `--runtime <file>`, that file. It has to be an `sn` of the same version, with every
   feature the program needs.
2. Otherwise, the installed runtime for the platform (this one, or `--target`) with the fewest
   features that has every one the program needs. See [Leaving features out](#leaving-features-out).
3. For this platform, the `sn` that's running, if nothing smaller is installed.

## Leaving features out

A few parts of Sonata need a native library that a program may have no use for:

| Feature | Library | What needs it |
|---|---|---|
| `sqlite` | SQLite | [`@sonata/sqlite`](../api/module/sqlite.md) |
| `tls` | Mbed TLS | TLS in [`@sonata/net`](../api/module/net.md): `https`, secure sockets |
| `zstd` | zstd | zstd in [`@sonata/compress`](../api/module/compress.md) and in responses of `@sonata/net` |
| `sodium` | libsodium | Password protection in [`@sonata/compress`](../api/module/compress.md) |

A program needs a feature when it may use a library that needs it, so the
[`build.libraries`](manifest.md#buildlibraries) list already decides most of them. To leave one
out while keeping the library, list it in `build.without`:

```luau
build = {
    libraries = { "fs", "net" },
    without = { "tls" }, -- plain HTTP only
},
```

Each combination of features has its own runtime, and the program is built from the one that has
exactly what it needs, so it carries none of the code it left out. Leaving out everything saves
about 2 MiB:

| Feature | Size in the executable |
|---|---|
| `sqlite` | about 1 MiB |
| `tls` | about 0.5 MiB |
| `zstd` | about 0.45 MiB |
| `sodium` | about 35 KiB |

What's left out behaves the same everywhere: `sn run`, `sn test` and the built program all refuse
it with a message that names the feature, like `TLS (https and secure sockets) in @sonata/net
isn't in this program: its build leaves out 'tls'`. Listing a library and leaving out the
feature it is (`sqlite`) is an error.

`sn` itself has every feature. The others come with each release, in
`sonata-<platform>-runtimes.tar.gz` (`.zip` for Windows): extract it into
`$SONATA_HOME/runtimes/<version>/<platform>/` and each runtime lands in a folder named after its
features, like `tls+zstd/sn` or `none/sn`. If the one a program needs isn't installed, `sn build`
uses the smallest one that has everything, turns off what the program left out so it still
behaves the same, and says what's missing.

### Building for another platform

Building for another platform is the same file copy, starting from that platform's `sn`:

```sh
sn build --target windows-x64
```

That file has to be in `$SONATA_HOME/runtimes/<version>/<target>/`, as `sn` (or `sn.exe`). It's
in the platform's `sonata-<target>-runtimes` release archive, with the runtimes that
[leave features out](#leaving-features-out); extract the whole archive into that folder. Each
runtime has to match your `sn` version exactly. [`sn doctor`](doctor.md) checks the ones you have.

The targets are `linux-x64`, `linux-arm64`, `macos-x64`, `macos-arm64`, `windows-x64` and
`windows-arm64`.

## Assets

Files listed in `build.assets` are packed into the executable and read with
[`@sonata/pocket`](../api/module/pocket.md):

```luau
-- project.luau
build = { assets = { "assets", "LICENSE" } },
```

```luau
local pocket = require("@sonata/pocket")
local logo = pocket.read("assets/logo.txt")
```

Under `sn run` the same files are read from disk, and only listed files are visible, so a
program can't come to depend on a file that won't be packed. Each package has its own assets:
a dependency's `assets/x` never collides with yours.

A built program doesn't load its assets when it starts: each is read from the executable when a
script asks for it. Large ones can be read in pieces with
[`pocket.open`](../api/module/pocket.md#pocketopen) or written to a file with
[`pocket.copy`](../api/module/pocket.md#pocketcopy), which keeps the executable bit, so a program
can carry a helper program and run it.

## The executable format

A built program is `sn` with a bundle appended to it:

```
[ sn executable ][ assets ][ payload ][ trailer (32 bytes) ]
```

At startup `sn` reads its own file. If it finds a trailer at the end, it runs the program in the
payload, and the command line never starts. The payload holds the compiled modules, the packages with their dependencies
and entrypoints, the list of allowed libraries, and where each asset is. It is zlib-compressed
unless `--no-compress` is given, and protected by a CRC-32.

Each asset is stored on its own, before the payload, and has its own CRC-32. With compression,
an asset is compressed too unless that wouldn't make it smaller (images and archives usually
are already).

Every `sn` also carries a short stamp with its version and platform, so a runtime for another
platform can be checked without running it.

The C++ side of this is documented in [`sonata::bundle`](../api/source/namespaces/bundle.md).

## Environment variables

| Variable | Used for |
|---|---|
| `SONATA_HOME` | Where runtimes for other platforms are kept. Default `~/.sonata`. |
