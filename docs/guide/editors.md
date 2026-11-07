# Editor support

Sonata projects work with the [Luau Language Server](https://github.com/JohnnyMorganz/luau-lsp),
which gives your editor completion, documentation on hover and type errors for the built-in
libraries, your packages and Sonata's globals.

Run this from anywhere inside a project:

```sh
sn init --lsp
```

Or set it up when you create the project:

```sh
sn init my-app --lsp
```

Your manifest and your code aren't touched, so it's safe to run at any time.

## VS Code

Open the project folder and install the extension VS Code recommends, **Luau Language Server**.
That's all: `sn init --lsp` has already written its settings.

## Other editors

Add `--no-vscode` to leave `.vscode` out:

```sh
sn init --lsp --no-vscode
```

The aliases in `.luaurc` work in any editor. The types of Sonata's globals have no such file, so
pass them when your editor starts the server:

```sh
luau-lsp lsp --definitions:@sonata=.sonata/types/globals.d.luau
```

## What it writes

| Path | What it's for | Commit it? |
|---|---|---|
| `.luaurc` | Aliases: `@sonata` to the types below, and one for each installed package. | Yes |
| `.sonata/types/` | The types of every built-in library and of the globals (`args`, `sonata`). | No |
| `.vscode/settings.json` | Tells the extension this isn't a Roblox project, and where the types of the globals are. | Yes |
| `.vscode/extensions.json` | Recommends the extension to anyone who opens the project. | Yes |

`.sonata/types/` is generated, so it's added to your `.gitignore`. After cloning a project that
uses this, run it once (or run `sn init --lsp`) and the types are back.

If you already have any of the JSON files, Sonata adds to them and keeps everything else in them.
The exception is a file with comments, which it couldn't write back: that file is left alone, and
`sn init --lsp` prints exactly what to add to it.

## Staying up to date

There's nothing to keep track of. In a project set up this way:

- `sn pkg add`, `remove` and `update` keep the package aliases in `.luaurc` in step with
  `.sonata/deps`.
- `sn run` and `sn build` do the same, and rewrite `.sonata/types/` if it doesn't match your `sn`,
  for example after upgrading Sonata. Your editor then sees the libraries you really have.

If one of these can't update the files, it prints a warning and carries on.

## Packages with their own entrypoint

`require("@name")` loads a package's entrypoint, and the alias in `.luaurc` follows it. The
language server only knows about `init.luau`, though, so for a package whose entrypoint is
something like `src/main.luau`, the alias points at that file. `@name` works as usual, but your
editor marks `require("@name/other")` as unknown, although it runs fine. Packages with an
`init.luau` as their entrypoint don't have this problem.
