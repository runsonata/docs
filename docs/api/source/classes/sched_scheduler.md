# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/sched">sched</a>::Scheduler</code> (Class)

Every VM has one scheduler. It is created the first time something asks for it, lives in the
Luau registry, and is destroyed by `lua_close()`. It owns everything that lets several Luau
threads ("tasks") make progress at once:

- the **ready queue**: threads to resume during the next cycle;
- **timers**: `task.wait`, `task.delay`;
- a **pool of worker threads** for blocking work (DNS lookups, child processes, reading stdin,
  file locks, ...);
- **socket readiness waits** (`poll` / `WSAPoll`);
- the bookkeeping behind `task.status`, `task.join` and `task.cancel`.

`#include <sonata/core/scheduler.hpp>`

## Concepts

### Suspending

The suspend functions (`sleep`, `await`, `waitIo`, `park`, `join`) only **yield** the calling
thread when the scheduler is the one running it: a task, or the program's entry script.
Anywhere else (a coroutine the script resumes by itself, a metamethod, a module being required,
a host that never runs the loop) the wait happens **inline**, on the C stack, and the scheduler's
loop keeps running meanwhile so other tasks still make progress. Code calling them rarely has to
care which happened, except where noted.

A wait that nothing can ever end (a `park` without a deadline while nothing else is pending)
ends at once and counts as timed out when it happens inline. A suspended task in that situation
simply never resumes: the loop ends when the only thing left is waiting forever.

Each suspend function must be the return value of the `lua_CFunction` calling it:

```cpp
int mySleep(lua_State* L) {
    const double seconds = luaL_checknumber(L, 1);
    return sched::Scheduler::of(L).sleep(L, seconds);
}
```

The functions that take a continuation `k` may instead return `kInline`, meaning the wait was
inline and is already over; the caller then carries on in the same C call. The C function must
have been registered with the same continuation (see
[`NativeFunction`](../namespaces/lib.md#nativefunction)).

### Running the loop

Hosts call `run()` after starting their entry thread ([`ModuleLoader::run`](luau_moduleloader.md#run)
does this). It returns once nothing is left that could ever happen: no ready thread, no timer, no
worker job, no socket wait. Threads waiting forever (`park` without deadline,
`task.wait(math.huge)`) don't keep it alive.

## Status

```cpp
enum class Status {
    Running,   // the thread that is running right now
    Normal,    // resumed another coroutine and waits for it
    Suspended, // yielded on its own; nothing will resume it
    Waiting,   // suspended on the scheduler (sleep, I/O, job, park)
    Scheduled, // queued to run (task.defer, task.delay, woken up)
    Done,      // returned
    Error,     // failed
    Cancelled, // stopped by cancel()
};
```

## Getting the scheduler

| Method | Description |
|---|---|
| `static Scheduler& of(lua_State* L)` | The scheduler of the VM `L` belongs to, created on first use. |
| `static Scheduler* find(lua_State* L)` | The same, or `nullptr` if the VM has none yet. |
| `double now() const` | Seconds on the scheduler's monotonic clock (0 = when it was created). |

`Scheduler` can't be copied.

## Starting threads

```cpp
lua_State* spawn(lua_State* L, int index);                 // runs now, until it first suspends
lua_State* defer(lua_State* L, int index);                 // runs at the end of this cycle
lua_State* delay(lua_State* L, double seconds, int index); // runs once "seconds" have passed
```

The function or suspended thread at `index`, with the values above it as its arguments, becomes
a task. The task's thread is left on top of `L`'s stack and returned. Argument errors are raised
on `L`.

```cpp
int resume(lua_State* thread, lua_State* from, int nargs);
```

Resumes `thread` now with `nargs` values from its own stack, exactly as the loop would (errors
are reported, results kept for `join`). Returns the `lua_resume` status.

## Suspending the calling thread

### `canSuspend`

```cpp
bool canSuspend(lua_State* L) const;
```

True if the suspend functions would yield `L` rather than wait inline.

### `sleep`

```cpp
int sleep(lua_State* L, double seconds);
```

Waits `seconds` (infinity = forever). The result pushed is how long it really took.

### `await`

```cpp
int await(lua_State* L, Job job, Continuation k = nullptr);
```

Runs `job` on a worker thread and waits for it. The completion's values are the results.

With a continuation `k`, Luau calls `k` once resumed, with the values on top of the stack; an
inline wait instead returns `kInline` with them pushed.

```cpp
return sched::Scheduler::of(L).await(L, [path]() -> sched::Completion {
    std::string data = slowRead(path);           // worker thread: no Lua here
    return [data](lua_State* T) {                // VM thread
        lua_pushlstring(T, data.data(), data.size());
        return 1;
    };
});
```

### `waitIo`

```cpp
int waitIo(lua_State* L, SocketHandle socket, int events, double deadline, Continuation k);
```

Waits until `socket` is ready for `events` (`kReadable` / `kWritable` bits), it is closed (see
`wakeIo`), or `deadline` (scheduler clock; infinity = none) passes. Nothing is pushed: try the
operation again to find out which. Needs a continuation; returns `kInline` for inline waits.

### `park` / `unpark`

```cpp
int park(lua_State* L, double deadline, Continuation k, std::uint64_t* token);
bool unpark(lua_State* thread, std::uint64_t token, const Push& push);
```

`park` waits until `unpark()` or `deadline`. Afterwards `timedOut(L)` says which; values given
to `unpark` are on top of the stack. Needs a continuation; returns `kInline` for inline waits.

`token` receives (before the thread suspends) the number `unpark()` needs. Store it with the
thread in whatever queue it waits in: a stale entry (the wait timed out, the thread was
cancelled, or even collected and its address reused) can then never wake the wrong wait.

`unpark` wakes a parked thread with the values `push` puts on its stack. It returns `false` if
that wait is already over. This is how channels, mutexes and events in `@sonata/task` are built.

### `timedOut`

```cpp
bool timedOut(lua_State* L);
```

Whether the last wait of `L` ended by its deadline. Reading it clears it.

### `wakeIo`

```cpp
void wakeIo(SocketHandle socket);
```

Ends every `waitIo()` on `socket` now. Call it before closing the socket.

## Managing threads

| Method | Description |
|---|---|
| `Status status(lua_State* L, lua_State* thread) const` | The thread's status. |
| `void cancel(lua_State* L, lua_State* thread)` | Stops `thread` for good: drops everything scheduled for it and closes it. Raises on `L` if the thread is running or normal. |
| `bool finished(lua_State* L, lua_State* thread) const` | Has `thread` returned, failed or been cancelled? |
| `int join(lua_State* L, lua_State* thread, double deadline, Continuation k)` | Waits until `thread` has finished (see `park` for `k` and `kInline`). If `timedOut(L)` is false afterwards, `pushOutcome()` tells how it ended. |
| `int pushOutcome(lua_State* L, lua_State* thread) const` | Pushes `true, ...results` or `false, error` (`false, "cancelled"` for a cancelled thread). Returns the count. |
| `bool watch(lua_State* L, lua_State* thread, std::function<void(bool failed)> fn, bool handlesErrors = true)` | Calls `fn` once `thread` has finished; `failed` is true if it raised or was cancelled. `fn` runs on the VM's thread between resumes and must not call into Lua (`unpark` is fine). Returns `false`, without keeping `fn`, if the thread has already finished. With `handlesErrors`, the thread's error isn't reported. |
| `lua_State* current() const` | The task running right now, or `nullptr`. |
| `std::size_t taskCount() const` | Threads that are scheduled or waiting. |
| `void setErrorHandler(ErrorHandler handler)` | Called when a task fails and nobody is joining it. Without a handler, the message and traceback go to stderr. |
| `bool isWaiting(lua_State* thread) const` | True while `thread` is suspended on the scheduler (as opposed to having yielded on its own). |

## Running the loop

| Method | Description |
|---|---|
| `bool step(bool wait = true)` | One cycle: collects finished jobs, ready sockets and due timers, then resumes what they woke. With `wait`, sleeps until something can happen first. Returns `false` (and does nothing) when nothing is left. |
| `void run()` | Runs cycles until nothing is left, `stop()` is called, or the critical thread fails. |
| `void stop()` | Makes `run()` return. |
| `void setCritical(lua_State* thread)` | When `thread` fails, `run()` stops and `fatalError()` holds its message and stack trace, instead of the error going to the error handler. `ModuleLoader::run` marks the entry script critical. |
| `const std::optional<std::string>& fatalError() const` | The critical thread's error, if it failed. |

## `Remote`

```cpp
class Remote {
public:
    bool post(std::function<void(lua_State* L)> fn);
};

std::shared_ptr<Remote> Scheduler::remote();
```

A handle other OS threads (signal handlers, watchers, ...) use to hand work to a VM's scheduler.
It is thread-safe, and safe to keep after the VM is gone: `post()` then simply returns `false`.

`post(fn)` runs `fn` on the VM's thread during the scheduler's next cycle. `fn` gets a thread
that belongs to the scheduler, on which it may push values, call functions and spawn tasks; its
stack is reset afterwards. A posted function doesn't keep the loop alive on its own.

```cpp
auto remote = sched::Scheduler::of(L).remote();
std::thread([remote] {
    waitForSomething();
    remote->post([](lua_State* L) {
        // back on the VM's thread: safe to use Lua here
    });
}).detach();
```
