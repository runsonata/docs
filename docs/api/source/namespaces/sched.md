# <code><a href="../sonata">sonata</a>::sched</code> (namespace)

The task scheduler: what lets many Luau threads make progress at once in one VM. The
[`@sonata/task`](../../module/task.md) library is a thin layer over it, and `net`, `process`,
`term` and `fs` use it so that a task waiting for I/O never blocks the others.

`#include <sonata/core/scheduler.hpp>`

## Classes & Structs

| Class | Description |
|---|---|
| [`Scheduler`](../classes/sched_scheduler.md) | The scheduler of one VM. |
| [`Remote`](../classes/sched_scheduler.md#remote) | A thread-safe handle other OS threads use to post work to a scheduler. |
| [`ThreadError`](#threaderror) | A task's failure, as given to an error handler. |

## Types

```cpp
// Pushes values onto a thread about to resume and returns how many, or pushes one error value
// and returns kRaise to raise it in the thread. Always runs on the VM's own OS thread.
using Push = std::function<int(lua_State* thread)>;

// A worker job's result: a Push that runs once the job has finished.
using Completion = Push;

// Work for a worker thread. Must not touch Lua. What it returns runs on the VM's thread
// afterwards. Exceptions become a Lua error.
using Job = std::function<Completion()>;

// A Luau continuation (lua_Continuation).
using Continuation = int (*)(lua_State* L, int status);

using ErrorHandler = std::function<void(const ThreadError&)>;

using SocketHandle = int;            // SOCKET (std::uintptr_t) on Windows
```

## Constants

| Name | Value | Meaning |
|---|---|---|
| `kRaise` | `-1` | Returned by a `Push` that pushed an error value to raise. |
| `kInline` | `-2` | Returned by the suspend functions that take a continuation when the wait happened inline and is already over: carry on in the same C call. |
| `kReadable` | `1` | `IoEvents` bit for `waitIo`. |
| `kWritable` | `2` | `IoEvents` bit for `waitIo`. |

## `ThreadError`

```cpp
struct ThreadError {
    lua_State* thread;     // the thread that failed (dead; its stack is intact)
    std::string message;   // the error value; non-string errors are described by their type
    std::string traceback; // may be empty
};
```
