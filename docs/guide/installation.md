# Installation

Sonata ships as two executables:

- **`sn`**: the command-line tool you use for everything.
- **`snrt`**: the runtime that `sn build` turns into standalone programs. You never run it
  yourself, but `sn build` has to be able to find it.

Sonata runs on Linux, macOS and Windows, on x64 and arm64.

# From the installation scripts (recommended)
Sonata offers installation scripts to automate the entire installation process into one command.

On Linux and MacOS:
```sh
curl -fsSL https://sonata.5418.org/install.sh | bash
```

or, if you dont have cUrl, use wget:

```
wget -qO- https://sonata.5418.org/install.sh | bash
```

On Windows, in PowerShell:
```ps
irm https://sonata.5418.org/install.ps1 | iex
```
## From a release

Prebuilt archives are attached to the
[GitHub releases](https://github.com/runsonata/sonata/releases), one per platform
(`sonata-<version>-<system>-<arch>.tar.gz`, or `.zip` on Windows). Each archive has this layout:

```
bin/sn                 the CLI
libexec/sonata/snrt    the runtime used by "sn build"
include/, lib/         headers and library, for embedding Sonata in C++
```

Extract the archive anywhere and add its `bin` folder to your `PATH`. Keep the folders
together: `sn` looks for `snrt` in `../libexec/sonata/` relative to itself.

## From source

### Requirements

| Requirement | Notes |
|---|---|
| CMake 3.21 or newer | |
| A C++20 compiler | GCC, Clang or MSVC. |
| zlib | Always required. |
| OpenSSL | Required for `@sonata/net` (TLS). |
| Git | Needed to clone the source, and at runtime by the package manager. |
| libzstd *(optional)* | Enables the `zstd` format in `@sonata/compress`. |
| libsodium *(optional)* | Enables password protection in `@sonata/compress`. |

On Debian or Ubuntu:

```sh
sudo apt install build-essential cmake git zlib1g-dev libssl-dev
# optional
sudo apt install libzstd-dev libsodium-dev
```

On macOS with Homebrew:

```sh
brew install cmake openssl
```

### Building

Clone the repository with its submodules (Luau and doctest):

```sh
git clone --recursive https://github.com/runsonata/sonata.git
cd sonata
```

=== "Linux / macOS"

    The repository includes a helper script, `b.sh`:

    ```sh
    ./b.sh release      # configure and build into build/release
    ./b.sh install      # install into $PREFIX (default: ~/.local)
    ```

    Make sure `~/.local/bin` (or `$PREFIX/bin`) is on your `PATH`.

=== "Windows"

    Use CMake directly from a Developer PowerShell:

    ```powershell
    cmake --preset release
    cmake --build --preset release --config Release
    cmake --install build/release --prefix "$env:LOCALAPPDATA\sonata"
    ```

    Then add `%LOCALAPPDATA%\sonata\bin` to your `PATH`. If CMake can't find zlib, install it
    with vcpkg and point `CMAKE_PREFIX_PATH` at it.

`b.sh` has a few more commands:

| Command | What it does |
|---|---|
| `./b.sh debug` | Configure and build a debug build into `build/debug` (the default). |
| `./b.sh release` | The same, as a release build in `build/release`. |
| `./b.sh run <args>` | Run the debug `sn` with `<args>`. |
| `./b.sh test [preset]` | Build and run the test suite with CTest (`debug` by default, or `release`). |
| `./b.sh install` | Install the release build into `$PREFIX` (default `~/.local`). |
| `./b.sh analyze` | Run clang-tidy over the sources. |
| `./b.sh clean` | Delete `build/`. |

### CMake options

| Option | Default | Description |
|---|---|---|
| `SONATA_BUILD_CLI` | `ON`¹ | Build `sn`. |
| `SONATA_BUILD_RUNTIME` | `ON`¹ | Build `snrt`. |
| `SONATA_BUILD_TESTS` | `ON`¹ | Build the unit tests. |
| `SONATA_INSTALL` | `ON`¹ | Generate install and packaging (CPack) rules. |
| `SONATA_LIBS` | every library | Semicolon-separated list of built-in libraries to compile in. |
| `SONATA_STATIC_DEPS` | `ON` | Link OpenSSL, zlib and the C++ runtime statically where static copies exist. |
| `SONATA_STANDALONE` | `OFF` | Build a runtime with no shared-library dependencies at all. Not possible on macOS. |
| `SONATA_COMPRESS_ZSTD` | `$SONATA_COMPRESS_ZSTD` | Enable zstd in `@sonata/compress` (needs libzstd). |
| `SONATA_COMPRESS_CRYPTO` | `$SONATA_COMPRESS_CRYPTO` | Enable passwords in `@sonata/compress` (needs libsodium). |

¹ When Sonata is the top-level CMake project. When it is added with `add_subdirectory()`, these
default to `OFF`.

## Checking the installation

```console
$ sn --version
sonata 0.1.8
$ sn --version --verbose
Sonata 0.1.8

  commit     b8cb8e2
  build      release
  platform   linux-x64
  compiler   gcc 13.2.0
  luau       0.739
```

Running `sn` with no arguments prints the list of commands.

!!! tip "Colors"

    `sn` colors its output when it writes to a terminal. Set `NO_COLOR=1` to turn colors off, or
    `FORCE_COLOR=1` to keep them when the output is piped.
