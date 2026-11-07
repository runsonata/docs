# Tasks and concurrency

Every Sonata program runs on a **scheduler**. It lets many pieces of code, called *tasks*, make
progress at once on a single OS thread, much like an event loop.

```luau
local task = require("@sonata/task")

task.spawn(function()
    for i = 1, 3 do
        print("tick", i)
        task.wait(0.5)
    end
end)

task.spawn(function()
    for i = 1, 3 do
        print("tock", i)
        task.wait(0.5)
    end
end)
-- prints tick 1, tock 1, tick 2, tock 2, ...
```

## How it works

- A task is a Luau thread (a coroutine) run by the scheduler. Your entry script is the first
  task.
- **Only one task runs at a time.** A task keeps running until it *waits*; then the scheduler
  runs another one. Nothing interrupts a task in the middle of ordinary Luau code.
- **The program ends when nothing is left to do:** every task has finished, or is waiting for
  something that can never happen (such as `task.wait(math.huge)`, or a channel nobody will
  ever send to).

## What waits without blocking

These operations let other tasks run while they wait:

| Library | Operations |
|---|---|
| [`@sonata/task`](../api/module/task.md) | `task.wait`, `task.join`, `task.all`, `task.race`, `task.timeout`, channels, mutexes, semaphores, events, groups |
| [`@sonata/net`](../api/module/net.md) | connecting, `send`, `recv*`, `accept`, DNS lookups, TLS handshakes |
| [`@sonata/process`](../api/module/process.md) | `process.exec`, `child:wait`, reading and writing pipes |
| [`@sonata/term`](../api/module/term.md) | reading from `term.stdin`, `term.prompt`, `term.readKey` |
| [`@sonata/fs`](../api/module/fs.md) | `watcher:next`, `fs.lock` |

Blocking work that the OS can't do asynchronously (DNS lookups, starting processes, file
locks, ...) runs on a pool of worker threads, so it never stalls the scheduler.

!!! warning "`sys.sleep` blocks everything"

    [`sys.sleep`](../api/module/sys.md) pauses the whole program, every task included. Use
    `task.wait` to pause only the current task.

CPU-heavy Luau code also blocks: a task that loops for ten seconds without waiting holds the
scheduler for ten seconds. Call `task.wait()` now and then in long loops to let other tasks run.

## Waiting where yielding isn't possible

Some places can't suspend a Luau thread: a metamethod, an iterator of a generic `for` loop, a
coroutine you resume yourself, or the top level of a module being required. A wait there still
works: the scheduler runs *inline*, right there, until the wait is over, and other tasks keep
making progress meanwhile. Your code doesn't need to care which of the two happened, but
waiting directly inside tasks is cheaper.

## Errors

- An error inside a task that nobody [joins](../api/module/task.md#taskjoin) is reported
  (message and stack trace on stderr), and that task ends. **The program keeps running.**
- [`task.onError(handler)`](../api/module/task.md#taskonerror) replaces the default report.
- An error in the **entry script** ends the program with status 1.

## Patterns

Run things in parallel and collect the results:

```luau
local results = task.all({
    function() return fetch("a") end,
    function() return fetch("b") end,
})
print(results[1], results[2])
```

Give up after a deadline:

```luau
local ok, value = task.timeout(5, function()
    return slowOperation()
end)
if not ok then
    print("failed:", value) -- "timed out" if it took too long
end
```

Producer and consumer:

```luau
local jobs = task.channel(10)

task.spawn(function()
    for i = 1, 100 do
        jobs:send(i)
    end
    jobs:close()
end)

while true do
    local ok, job = jobs:recv()
    if not ok then break end -- closed and drained
    print("working on", job)
end
```

See [`@sonata/task`](../api/module/task.md) for the full API, and
[`sonata::sched::Scheduler`](../api/source/classes/sched_scheduler.md) for how C++ code
integrates with the scheduler.
