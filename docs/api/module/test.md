# @sonata/test

Test cases and assertions. Put tests in files named `*.test.luau` and run them with
[`sn test`](../../guide/testing.md).

```luau
local test = require("@sonata/test")
local util = require("./util")

test.group("util.slug", function()
    test.case("lowercases", function()
        test.equal(util.slug("Hello World"), "hello-world")
    end)

    test.case("rejects empty text", function()
        test.raises(function()
            util.slug("")
        end, "empty")
    end)
end)
```

A case runs where it's declared, and cases run one after another, so a test file is an ordinary
program: cases can wait ([`task.wait`](task.md), sockets, child processes) and require modules
like any other code. A failed assertion stops its case and reports the line it was called from;
the next case runs as usual.

Outside `sn test`, for example with `sn run -e tests/util.test.luau`, the cases still run and
each result is printed, but there's no summary or exit status.

## Cases and groups

### test.case

```luau
test.case(name: string, fn: () -> ())
```

Runs a test case now. It fails if `fn` raises, whether through an assertion or not. A failure
that isn't an assertion (a bug in the code under test) is reported with a stack trace.

### test.group

```luau
test.group(name: string, fn: () -> ())
```

Runs `fn` now. The cases it declares are named `"name > case"`, and groups can be nested. An
error in `fn` outside any case is reported as a failure under the group's name.

### test.skip

```luau
test.skip(name: string, fn: (() -> ())?)
```

Reports a case as skipped without running it. `fn` is accepted so that turning a case off is a
one-word change.

### test.beforeEach

```luau
test.beforeEach(fn: () -> ())
```

Runs `fn` before each case declared after it in the current group, nested groups included.
Hooks of outer groups run first. If a hook fails, so does the case.

### test.afterEach

```luau
test.afterEach(fn: () -> ())
```

Runs `fn` after each case declared after it in the current group, even one that failed. Hooks
of inner groups run first. A failure here fails the case, unless it already failed.

## Assertions

Each assertion takes an optional `message`, which is put in front of the failure:
`test.equal(count, 3, "items")` fails with `items: expected 3, got 2`.

### test.equal

```luau
test.equal(actual: any, expected: any, message: string?)
```

Fails unless `actual` equals `expected`. Tables are compared by what they hold, recursively
(their metatables aren't compared), buffers by their bytes, and NaN equals NaN. Tables that
contain themselves are fine. The failure says where they differ:

```luau
test.equal({ a = { 1, 2 } }, { a = { 1, 3 } })   --> at .a[2]: expected 3, got 2
test.equal({ a = 1 }, { a = 1, b = 2 })           --> at .b: expected 2, got nothing
test.equal("x", "y")                              --> expected "y", got "x"
```

### test.notEqual

```luau
test.notEqual(actual: any, expected: any, message: string?)
```

Fails if `actual` equals `expected`, compared like `test.equal`.

### test.ok

```luau
test.ok(value: any, message: string?)
```

Fails unless `value` is neither `false` nor `nil`.

### test.near

```luau
test.near(actual: number, expected: number, tolerance: number?, message: string?)
```

Fails unless `actual` is within `tolerance` (default `1e-9`) of `expected`, for numbers that
come out of arithmetic: `test.near(0.1 + 0.2, 0.3)`.

### test.raises

```luau
test.raises(fn: () -> (), fragment: string?, message: string?): string
```

Fails unless `fn` raises an error, and, if `fragment` is given, one whose message contains it
(plain text, not a pattern). Returns the error message, for checking further.

```luau
local message = test.raises(function()
    json.decode("{")
end, "expected string key")
```

### test.fail

```luau
test.fail(message: string?): never
```

Fails the case now.
