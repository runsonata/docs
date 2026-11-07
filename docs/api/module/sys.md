# @sonata/sys

Facts about the machine the program runs on, plus clocks and sleeping. Facts about the running
program itself (pid, arguments, environment, working directory) are in
[`@sonata/process`](process.md).

```luau
local sys = require("@sonata/sys")
```

**Errors:** queries that can fail return `nil` instead of raising.

## Constants

| Name | Value |
|---|---|
| `sys.os` | `"windows"`, `"macos"`, `"linux"`, `"freebsd"`, `"android"` or `"unknown"`. |
| `sys.arch` | The machine's architecture: `"x86_64"`, `"aarch64"`, `"x86"`, `"arm"`, `"riscv64"`, ... This can differ from the program's own architecture under emulation. |
| `sys.endianness` | `"little"` or `"big"`. |
| `sys.eol` | `"\n"`, or `"\r\n"` on Windows. |
| `sys.pathSeparator` | `"/"`, or `"\\"` on Windows. |
| `sys.pathDelimiter` | `":"`, or `";"` on Windows, as used in `PATH`. |
| `sys.devNull` | `"/dev/null"`, or `"NUL"` on Windows. |

## Machine

| Function | Returns |
|---|---|
| `sys.hostname(): string?` | The machine's host name. |
| `sys.username(): string?` | The user the program runs as. |
| `sys.homeDir(): string?` | That user's home directory. |
| `sys.tempDir(): string?` | The temporary directory. |
| `sys.osVersion(): string?` | The OS or kernel release, e.g. `"6.8.0-45-generic"`. |
| `sys.cpuCount(): number` | The number of logical processors, at least 1. |
| `sys.totalMemory(): number?` | Bytes of physical memory. |
| `sys.freeMemory(): number?` | Bytes of memory available to programs. |
| `sys.pageSize(): number?` | Bytes per memory page. |
| `sys.uptime(): number?` | Seconds since the machine booted. |
| `sys.loadAverage(): { number }?` | The 1, 5 and 15 minute load averages. `nil` on Windows. |

### sys.info

```luau
sys.info(): { [string]: any }
```

Every constant and every query above, collected into one table (with the same names).

```luau
for key, value in sys.info() do
    print(key, value)
end
```

## Time

### sys.time

```luau
sys.time(): number
```

Wall-clock time: seconds since the Unix epoch, with a fractional part. For dates and time zones,
see [`@sonata/datetime`](datetime.md).

### sys.clock

```luau
sys.clock(): number
```

Monotonic seconds from an arbitrary starting point. Use it to measure durations: it never
jumps when the system clock is changed.

```luau
local start = sys.clock()
doWork()
print(`took {sys.clock() - start} s`)
```

### sys.sleep

```luau
sys.sleep(seconds: number): ()
```

Pauses the **whole program**, blocking every task. To pause only the current task and let
others run, use [`task.wait`](task.md#taskwait).
