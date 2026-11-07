# Installation

Sonata is one file: `sn`. It's the command-line tool, and also the runtime inside every program
it builds. It has no dependencies, so there's nothing else to install.

Sonata runs on Linux (any distribution, and Android through Termux), macOS and Windows, on x64
and arm64.

## From the installation scripts (recommended)

On Linux and macOS:

```sh
curl -fsSL https://sonata.5418.org/install.sh | sh
```

or, if you don't have cURL, use wget:

```sh
wget -qO- https://sonata.5418.org/install.sh | sh
```

On Windows, in PowerShell:

```powershell
irm https://sonata.5418.org/install.ps1 | iex
```

The script downloads `sn` for your platform, checks it against the release's checksums, makes
sure it runs, and adds it to your `PATH`. It doesn't need root, and it installs nothing else.

| Option | Variable | Description |
|---|---|---|
| `--version <version>` | `SONATA_VERSION` | Install this release instead of the latest. |
| `--dir <path>` | `SONATA_HOME` | Install here instead of `~/.sonata`. |
| `--no-modify-path` | `SONATA_NO_MODIFY_PATH=1` | Don't add `sn` to your `PATH`. |

On Windows the options are `-Version`, `-Dir` and `-NoModifyPath`.

To pass options through a pipe, use `sh -s --`:

```sh
curl -fsSL https://sonata.5418.org/install.sh | sh -s -- --version 2.0.0
```

## From a release

Prebuilt archives are attached to the
[GitHub releases](https://github.com/runsonata/sonata/releases), one per platform
(`sonata-<system>-<arch>.tar.gz`, or `.zip` on Windows). Extract one and put `bin/sn` anywhere on
your `PATH`. It's the only file Sonata needs, so you can move it wherever you like.

## From source

You need CMake 3.25 or newer, a C++20 compiler (GCC, Clang or MSVC) and Git. Everything else
comes with the source.

```sh
git clone --recursive https://github.com/runsonata/sonata.git
cd sonata
```

=== "Linux / macOS"

    ```sh
    ./b.sh release
    ```

    The result is `build/release/app/sn`. Copy it to a folder on your `PATH`.

=== "Windows"

    From a Developer PowerShell:

    ```powershell
    cmake --preset release
    cmake --build --preset release
    ```

    The result is `build\release\app\Release\sn.exe`. Copy it to a folder on your `PATH`.

`b.sh` has a few more commands:

| Command | What it does |
|---|---|
| `./b.sh debug` | Configure and build a debug build into `build/debug` (the default). |
| `./b.sh release` | The same, as a release build in `build/release`. |
| `./b.sh package` | A static build, the way releases are made. On Linux, use a musl toolchain. |
| `./b.sh run <args>` | Run the debug `sn` with `<args>`. |
| `./b.sh test [preset]` | Build and run the tests with CTest (`debug` by default, or `release`). |
| `./b.sh clean` | Delete `build/`. |

## Checking the installation

```console
$ sn --version
sonata 2.0.0
```

[`sn doctor`](doctor.md) checks the rest: that `sn` is on your `PATH`, that nothing older is
getting in its way, and that this machine can build and run programs.

!!! tip "Colors"

    `sn` colors its output when it writes to a terminal. Use `--color never` or set `NO_COLOR=1`
    to turn colors off, and `--color always` or `FORCE_COLOR=1` to keep them when the output is
    piped.
