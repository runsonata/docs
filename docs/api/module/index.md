---
search:
  boost: 2
---

# Module API Reference

This section documents what Luau code running under Sonata can use: the globals Sonata adds,
and the built-in libraries.

!!! note

    This is the **Luau** API. For Sonata's C++ internals, see the
    [C++ API reference](../source/index.md).

## Globals

| Global | Description |
|---|---|
| [`require`](globals.md#require) | Loads modules, packages and built-in libraries. |
| [`args`](globals.md#args) | The program's arguments. |
| [`sonata`](globals.md#sonata) | Information about the running program. |

## Built-in libraries

Built-in libraries are compiled into Sonata. Import them with `require("@sonata/<name>")`:

```luau
local fs = require("@sonata/fs")
```

| Library | Description |
|---|---|
| [`@sonata/compress`](compress.md) | gzip, zlib, deflate and zstd compression, streaming, checksums. |
| [`@sonata/crypto`](crypto.md) | Hashes, HMAC, key derivation, ciphers, signatures, random values, UUIDs. |
| [`@sonata/datetime`](datetime.md) | Dates, times and time zones, precise to the nanosecond. |
| [`@sonata/fs`](fs.md) | Files, directories, globbing, watching and locking. |
| [`@sonata/json`](json.md) | Parse, serialize and edit JSON. |
| [`@sonata/net`](net.md) | TCP, UDP, Unix sockets, TLS, DNS, IP addresses, URLs, HTTP/1.1 and WebSocket wire formats. |
| [`@sonata/path`](path.md) | Lexical path manipulation for POSIX and Windows. |
| [`@sonata/pocket`](pocket.md) | Read-only asset files packed with the program. |
| [`@sonata/process`](process.md) | The running program, child processes and signals. |
| [`@sonata/regex`](regex.md) | ECMAScript regular expressions. |
| [`@sonata/serde`](serde.md) | YAML, TOML, INI, CSV and TSV, plus a toolkit for custom formats. |
| [`@sonata/sonata`](sonata.md) | Sonata's own internals: build info, projects and the package manager. |
| [`@sonata/sys`](sys.md) | Facts about the machine, clocks and sleeping. |
| [`@sonata/task`](task.md) | Tasks and the tools to coordinate them. |
| [`@sonata/term`](term.md) | Standard streams, colors, cursor control and keyboard input. |

Library tables are read-only. A project can limit which libraries it may use with
[`build.libraries`](../../guide/manifest.md#buildlibraries).

## Conventions

Signatures on these pages use Luau type syntax:

```luau
fs.copyFile(from: string, to: string, overwrite: boolean?): ()
```

- A `?` after a type means the argument may be omitted or `nil`.
- `(nil, string)` as a result means the function returns `nil` and an error message on failure.
- Methods are written `object:method(...)`.

Libraries differ in how they report failure, and each page says which applies:

- **Raise**: the function raises a Luau error (catch it with `pcall`). Used by `fs`, `path`,
  `json`, `regex`, `serde`, `sonata` and `pocket.read`.
- **Return `nil, message`**: failures that depend on the outside world return `nil` and a
  message; only misuse (bad argument types) raises. Used by `net`, `term` streams, and parts of
  `process` and `crypto`.
