---
hide:
  - navigation
  - toc
---

# Sonata

**Sonata is an all-in-one toolkit for [Luau](https://luau.org).** It gives you one command, `sn`, that
creates projects, manages their dependencies, runs them, and compiles them into standalone
executables that run on machines without Sonata installed.

```luau
local fs = require("@sonata/fs")
local term = require("@sonata/term")
local task = require("@sonata/task")

for _, name in fs.listDir(".") do
    task.spawn(function()
        term.stdout:writeLine(term.style(name, "bold", "cyan"))
    end)
end
```

## What you get

- **A project layout and a manifest.** `sn init` creates a project, and `.sonata/project.luau`
  describes it: its name, its entry script, its dependencies and how to build it.
- **Modules.** `require("./util")` loads files relative to the script, and `require("@name")`
  loads installed packages.
- **A package manager.** Dependencies are plain Git repositories. `sn pkg` installs, updates,
  removes and inspects them, and a lock file pins the exact commits.
- **15 built-in libraries.** Filesystem, paths, processes, the terminal, networking with TLS,
  JSON/YAML/TOML/CSV, cryptography, dates and time zones, compression, regular expressions,
  tasks and more. Import them with `require("@sonata/<name>")`.
- **Tasks.** Every program runs on a scheduler. Waiting for a socket, a child process, a timer
  or a channel lets the other tasks run.
- **Standalone executables.** `sn build` compiles your project and its dependencies into
  one file. It can also build a smaller runtime containing only the libraries you use.

## Where to go next

<div class="grid cards" markdown>

- **[Installation](guide/installation.md)**: install `sn` or build it from source.
- **[Your first project](guide/first-project.md)**: create, run and build a project in five minutes.
- **[Module API reference](api/module/index.md)**: every built-in library and global, function by function.
- **[C++ API reference](api/source/index.md)**: embed Sonata, extend it, or work on its source.

</div>

## Getting help

- Source code and issues: [github.com/Sonata-CLI/sonata](https://github.com/Sonata-CLI/sonata)
- Community: [Discord](https://discord.gg/kGVWCdVHvW)
