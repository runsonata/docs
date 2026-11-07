# Guide

The guide walks through Sonata from installing it to shipping a standalone program. Read it
in order the first time; afterwards each page works as a reference for its topic.

| Page | What it covers |
|---|---|
| [Installation](installation.md) | Installing `sn`, or building it from source. |
| [Your first project](first-project.md) | `sn init`, the project layout, `sn run`, script arguments and `sn build`. |
| [The project manifest](manifest.md) | Every field of `.sonata/project.luau`, including the `build` table and `--!strict`. |
| [Modules and require](modules.md) | Relative requires, `init.luau`, `@` aliases and built-in libraries. |
| [Packages](packages.md) | Declaring dependencies, the lock file and `sn pkg`. |
| [Building executables](building.md) | `sn build`, library selection, assets, runtimes and environment variables. |
| [Editor support](editors.md) | `sn init --lsp`: completion and type errors with the Luau Language Server. |
| [Checking your setup](doctor.md) | `sn doctor`: finding what's wrong with your installation or project. |
| [Tasks and concurrency](tasks.md) | How the scheduler runs tasks, and what waits without blocking. |
| [CLI reference](cli.md) | Every `sn` command and option. |

For the details of a single function, see the [module API reference](../api/module/index.md).
