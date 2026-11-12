# Testing

Tests are Luau files named `*.test.luau`, anywhere in the project. They use
[`@sonata/test`](../api/module/test.md), and `sn test` runs them.

```
my-app/
├── .sonata/project.luau
├── main.luau
├── util.luau
└── tests/
    └── util.test.luau
```

```luau
-- tests/util.test.luau
local test = require("@sonata/test")
local util = require("../util")

test.case("slug lowercases", function()
    test.equal(util.slug("Hello World"), "hello-world")
end)

test.case("slug rejects empty text", function()
    test.raises(function()
        util.slug("")
    end, "empty")
end)
```

```console
$ sn test
✓ tests/util.test.luau  2 passed  3 ms

✓ 2 passed in 1 file, 5 ms
```

A failure shows the case, the line, and what was wrong, and `sn test` exits with status 1:

```console
$ sn test
✗ tests/util.test.luau  1 failed, 1 passed  4 ms
    ✗ slug lowercases
      tests/util.test.luau:6: expected "hello-world", got "hello world"

✗ 1 failed, 1 passed in 1 file, 6 ms
```

## How tests run

Each test file runs as a program of its own, in its own VM, the way `sn run` would run it: the
same dependencies, `@` aliases and [assets](building.md#assets), and the same
[`build.libraries`](manifest.md#buildlibraries), with `@sonata/test` added. Nothing one file
does (globals, module state) reaches another. Files run one after another, in path order.

Inside a file, a case runs where it's declared. That keeps a test file an ordinary program:
cases can wait for timers, sockets or child processes, and code between cases runs in order.
A case that fails doesn't stop the others. An error outside any case ends the file, and is
reported as the file failing to run.

Test files are never part of the program: `sn build` leaves out every `*.test.luau` file, and
[`sn doctor`](doctor.md) doesn't ask for `test` in `build.libraries`.

## Groups and hooks

Groups name related cases and share setup:

```luau
test.group("cache", function()
    local cache

    test.beforeEach(function()
        cache = Cache.new()
    end)

    test.case("starts empty", function()
        test.equal(cache:size(), 0)
    end)

    test.case("keeps what's put in", function()
        cache:put("a", 1)
        test.equal(cache:get("a"), 1)
    end)
end)
```

These cases are named `cache > starts empty` and `cache > keeps what's put in`. `afterEach`
runs after every case, including ones that failed, so it's the place for cleanup such as
removing temporary files.

## Choosing what runs

```sh
sn test                          # every test file in the project
sn test tests/parser.test.luau   # one file
sn test tests/net                # the test files in a folder
sn test -f cache                 # cases whose name contains "cache"
sn test -f parse -f print        # either
sn test -v                       # list every case, not just the failures
```

Without a path, `sn test` looks for the project from the current folder upwards, like `sn run`.

A single test file can also be run with `sn run -e tests/util.test.luau`, which prints each
result without a summary.
