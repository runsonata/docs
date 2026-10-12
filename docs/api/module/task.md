# @sonata/task

Tasks (lightweight threads) and the tools to coordinate them.

```luau
local task = require("@sonata/task")
```

Tasks are Luau threads run by the program's scheduler. Only one runs at a time; a task gives
the others a turn whenever it waits (`task.wait`, a socket read, a child process, a channel,
...). The program keeps running until every task has finished or is waiting for something that
can never happen. [Tasks and concurrency](../../guide/tasks.md) explains the model.

Wherever a function `fn` is expected below, a suspended coroutine works too: it is resumed with
the extra arguments instead of a new thread being created.

## Starting and stopping

### task.spawn

```luau
task.spawn(fn: (...any) -> ...any, ...: any): thread
```

Runs `fn(...)` as a new task **right now**, until it first waits, then returns its thread.

### task.defer

```luau
task.defer(fn: (...any) -> ...any, ...: any): thread
```

Runs `fn(...)` as a new task at the end of the current scheduler cycle.

### task.delay

```luau
task.delay(seconds: number, fn: (...any) -> ...any, ...: any): thread
```

Runs `fn(...)` as a new task once `seconds` have passed.

### task.wait

```luau
task.wait(seconds: number?): number
```

Suspends the current task for `seconds` (default `0`: until the next cycle) and returns how long
it really waited. Other tasks run in the meantime. `task.wait(math.huge)` waits forever.

### task.cancel

```luau
task.cancel(thread: thread): ()
```

Stops a task for good, wherever it is waiting. Raises if the thread is the one running or one
that resumed it.

## Managing tasks

### task.running

```luau
task.running(): thread?
```

The task running right now, or `nil` outside of one.

### task.status

```luau
task.status(thread: thread): Status
```

| Status | Meaning |
|---|---|
| `"running"` | The thread running right now. |
| `"normal"` | It resumed another coroutine and waits for it. |
| `"suspended"` | It yielded on its own; nothing will resume it. |
| `"waiting"` | Suspended on the scheduler (sleep, I/O, a channel, ...). |
| `"scheduled"` | Queued to run (`defer`, `delay`, or woken up). |
| `"done"` | Returned. |
| `"error"` | Failed. |
| `"cancelled"` | Stopped by `task.cancel`. |

### task.join

```luau
task.join(thread: thread, timeout: number?): (boolean?, ...any)
```

Waits for a task to finish.

- `true, ...results` if it returned;
- `false, error` if it failed (the error is returned, not raised, and isn't reported);
- `nil, "timed out"` if `timeout` seconds passed first.

A cancelled task gives `false, "cancelled"`.

### task.all

```luau
task.all(tasks: { (() -> any) | thread }): { any }
```

Runs the functions as tasks and waits for all of them. Each entry of the result is that task's
first result. The first error is raised, and the tasks still running are cancelled.

```luau
local pages = task.all({
    function() return download("a") end,
    function() return download("b") end,
})
```

### task.race

```luau
task.race(tasks: { (() -> ...any) | thread }): (number, ...any)
```

Runs the functions as tasks; the first to finish wins and the others are cancelled. Returns the
winner's index and results. Raises if the winner failed.

### task.timeout

```luau
task.timeout(seconds: number, fn: (...any) -> ...any, ...: any): (boolean, ...any)
```

Runs `fn(...)` as a task and cancels it after `seconds`. Returns `true, ...results`, or
`false, error`; the error is `"timed out"` if time ran out.

### task.count

```luau
task.count(): number
```

The number of tasks that are scheduled or waiting.

### task.onError

```luau
task.onError(handler: ((message: string, traceback: string, thread: thread) -> ())?): ()
```

Sets the function called (as a new task) when a task fails and nobody joins it. `nil` restores
the default, which prints the message and traceback to stderr. Errors in tasks never stop the
program; an error in the main script still does.

## Coordination

Every wait below takes an optional `timeout` in seconds.

### task.channel

```luau
task.channel(capacity: number?): Channel
```

A queue for passing values between tasks. With `capacity` (`n > 0`), `send` waits while the
channel holds `n` values. With `capacity = 0`, every `send` waits for a receiver. Without a
capacity, the channel is unbounded.

| Method | Returns |
|---|---|
| `ch:send(value, timeout?)` | `true`, or `false, "closed"`, or `false, "timed out"`. |
| `ch:recv(timeout?)` | `true, value`, or `false, "closed"`, or `false, "timed out"`. |
| `ch:trySend(value)` | `boolean`. Never waits. |
| `ch:tryRecv()` | `true, value`, or `false`. Never waits. |
| `ch:close()` | Wakes every waiter. Values already sent can still be received. |
| `ch:isClosed()` | `boolean`. |
| `ch:len()` or `#ch` | The number of values waiting to be received. |
| `ch:capacity()` | The capacity (`math.huge` for an unbounded channel). |

```luau
local results = task.channel()
for i = 1, 3 do
    task.spawn(function()
        results:send(i * i)
    end)
end
for _ = 1, 3 do
    local _, value = results:recv()
    print(value)
end
```

### task.mutex

```luau
task.mutex(): Mutex
```

| Method | Returns |
|---|---|
| `m:lock(timeout?)` | `boolean`: whether the lock was acquired. |
| `m:tryLock()` | `boolean`. Never waits. |
| `m:unlock()` | |
| `m:isLocked()` | `boolean`. |

Not reentrant, and only the thread that locked it may unlock it.

### task.semaphore

```luau
task.semaphore(permits: number): Semaphore
```

| Method | Returns |
|---|---|
| `s:acquire(timeout?)` | `boolean`. |
| `s:tryAcquire()` | `boolean`. Never waits. |
| `s:release()` | |
| `s:available()` | The number of free permits. |

### task.event

```luau
task.event(): Event
```

A flag tasks can wait for.

| Method | Returns |
|---|---|
| `e:wait(timeout?)` | `boolean`: `true` once the event is set, `false` on timeout. |
| `e:set()` | Sets the flag and wakes every waiter. |
| `e:reset()` | Clears the flag. |
| `e:isSet()` | `boolean`. |

### task.group

```luau
task.group(): Group
```

Tasks managed together.

| Method | Returns |
|---|---|
| `g:spawn(fn, ...)` | `thread`. Starts a task in the group. |
| `g:wait(timeout?)` | `ok, { error }` once every task has finished (`ok` is `false` if any failed), or `nil, "timed out"`. |
| `g:cancel()` | Cancels every task in the group. |
| `g:count()` | The number of tasks still running. |

## Waiting where yielding isn't possible

A wait inside something that can't yield (a metamethod, a `for`-loop iterator, a coroutine you
resume yourself, a module's top level) still works: it runs the scheduler right there until the
wait is over. Prefer waiting directly in tasks.
