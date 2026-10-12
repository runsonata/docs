# @sonata/process

The running program, the child processes it starts, and signals. Facts about the machine
itself (OS, CPU, memory, ...) are in [`@sonata/sys`](sys.md).

```luau
local process = require("@sonata/process")
```

**Errors:** a program that can't be started raises an error; one that exits with a non-zero
code does not (`ok` is `false`). Waiting (`exec`, `wait`, pipe reads and writes) lets other
tasks run.

## The running program

| Field | Description |
|---|---|
| `process.pid: number` | This process's ID. |
| `process.ppid: number?` | The parent's process ID (`nil` if it can't be determined). |
| `process.execPath: string?` | The path of the running executable (`nil` if it can't be determined). Under `sn run` this is `sn` itself. |
| `process.args: { string }` | The program's arguments; the same array as the [`args`](globals.md#args) global. |
| `process.env` | The environment variables (see below). |

### process.env

`process.env` behaves like a table of environment variables:

```luau
print(process.env.HOME)          --> "/home/me" (nil if unset)
process.env.FOO = "bar"          -- set a variable
process.env.FOO = nil            -- remove it
for name, value in process.env do
    print(name, value)
end
```

Changes apply to this process and to child processes started afterwards.

### process.cwd / process.chdir

```luau
process.cwd(): string
process.chdir(path: string): ()
```

Get or change the current working directory.

### process.uptime

```luau
process.uptime(): number
```

Seconds since the program started.

### process.memoryUsage

```luau
process.memoryUsage(): { rss: number?, luauHeap: number }
```

`rss` is the bytes of RAM the process uses (`nil` if unknown); `luauHeap` is the bytes used by
this VM's heap.

### process.exit

```luau
process.exit(code: number?): never
```

Ends the program immediately with `code` (default `0`). Standard output is flushed.

## Running a program to completion

### process.exec

```luau
process.exec(program: string, args: { string }?, options: ExecOptions?): ExecResult

type ExecOptions = {
    cwd: string?,                  -- working directory of the child
    env: { [string]: string }?,    -- added to / overriding the inherited environment
    stdin: string?,                -- data fed to the child's stdin
    shell: boolean?,               -- run through /bin/sh (cmd.exe on Windows); default false
    stdio: ("pipe" | "inherit")?,  -- "pipe" (default) captures stdout/stderr, "inherit" shares ours
}

type ExecResult = {
    ok: boolean,      -- exited with code 0
    code: number,     -- the exit code
    stdout: string,
    stderr: string,
}
```

Runs a program, waits for it and collects its output. Arguments are passed directly, without a
shell, unless `shell = true`. With `stdio = "inherit"` the child shares the terminal, and
`stdout` and `stderr` are `""`.

```luau
local result = process.exec("git", { "status", "--short" }, { cwd = "repo" })
if result.ok then
    print(result.stdout)
else
    print("git failed:", result.code, result.stderr)
end
```

## Talking to a running program

### process.spawn

```luau
process.spawn(program: string, args: { string }?, options: SpawnOptions?): Child

type SpawnOptions = {
    cwd: string?,
    env: { [string]: string }?,
    shell: boolean?,
    stdin: ("pipe" | "inherit" | "null")?,   -- default "pipe"
    stdout: ("pipe" | "inherit" | "null")?,  -- default "pipe"
    stderr: ("pipe" | "inherit" | "null")?,  -- default "pipe"
    stdio: ("pipe" | "inherit" | "null")?,   -- sets all three; the individual options win
    detached: boolean?,  -- own session / process group: survives our Ctrl+C (default false)
}
```

Starts a program and returns immediately with a `Child`.

```luau
local child = process.spawn("python3", { "-i" }, { stderr = "inherit" })
child.stdin:write("print(1 + 1)\n")
child.stdin:close()
print(child.stdout:readAll()) --> "2\n"
print(child:wait().code)      --> 0
```

### Child

| Member | Description |
|---|---|
| `child.pid: number` | The child's process ID. |
| `child.stdin`, `child.stdout`, `child.stderr` | Pipes, for streams set to `"pipe"` (otherwise `nil`). |
| `child:wait(timeout: number?)` | Waits for the child to exit. Returns `{ ok, code, signal? }`, or `nil, "timed out"`. |
| `child:status()` | `nil` while it runs; the same table as `wait()` once it has exited. |
| `child:kill(signal: Signal?): boolean` | Sends a signal (default `"terminate"`). |

A child killed by a signal reports `code` as `128 + signal`, like a shell would, and `wait()`
names the signal. A child that is never waited for is reaped in the background.

### Pipes

| Method | Description |
|---|---|
| `pipe:write(data: string)` | `true`, or `nil, err`. (stdin) |
| `pipe:close()` | Closes the pipe; on stdin this sends end-of-file. |
| `pipe:read(max: number?): string?` | Whatever is available, up to `max` bytes (default 64 KiB). `nil` at end of file. |
| `pipe:readLine(keepEnding: boolean?): string?` | The next line. `nil` at end of file. |
| `pipe:readAll(): string` | Everything until end of file. |

A read waits for data without blocking other tasks. Reading the same pipe from two tasks is
safe; they take turns.

## Signals

### process.kill

```luau
process.kill(pid: number, signal: Signal?): (boolean?, string?)
```

Sends a signal (default `"terminate"`) to a process. Returns `true`, or `nil, err`.

### process.onSignal

```luau
process.onSignal(signal: Signal, handler: ((name: string) -> ())?): ()
```

Each time the signal arrives, `handler(signalName)` runs as a new task. Passing `nil` restores
the default behavior (usually: exit). A handler doesn't keep the program alive by itself.

```luau
process.onSignal("interrupt", function()
    print("cleaning up...")
    process.exit(130)
end)
```

### Signal names

| Name | POSIX signal | Notes |
|---|---|---|
| `"interrupt"` | `SIGINT` | Ctrl+C. |
| `"terminate"` | `SIGTERM` | |
| `"hangup"` | `SIGHUP` | On Windows: the console was closed. |
| `"quit"` | `SIGQUIT` | |
| `"user1"`, `"user2"` | `SIGUSR1`, `SIGUSR2` | |
| `"resize"` | `SIGWINCH` | The terminal was resized. |
| `"alarm"` | `SIGALRM` | |
| `"continue"` | `SIGCONT` | |
| `"kill"`, `"stop"` | `SIGKILL`, `SIGSTOP` | For sending only. |
| `"break"` | | Windows only: Ctrl+Break. |

`"SIGINT"`, `"INT"` and plain numbers work too. On Windows only `"interrupt"`, `"break"` and
`"hangup"` can be handled, and sending any signal terminates the process.

!!! note

    `process.exit` uses `std::exit`: stdio is flushed and `atexit` handlers run, but C++ objects
    on the host's stack are not destroyed.
