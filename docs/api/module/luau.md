# @sonata/luau

Compile, load and run Luau code: in the running VM with an environment of your choice, or in
isolated VMs with their own globals, a memory limit and a time limit.

```luau
local luau = require("@sonata/luau")

print(luau.eval("return 6 * 7")) --> 42

local vm = luau.vm({ timeout = 1, memoryLimit = 8 * 1024 * 1024 })
vm:set("greet", function(name) return "hello " .. name end)
print(vm:run("return greet(...)", "world")) --> hello world
```

The library offers two levels of isolation:

| | In this VM | Isolated VM |
|---|---|---|
| Functions | [`load`](#luauload), [`eval`](#luaueval), [`env`](#luauenv) | [`luau.vm`](#luauvm) |
| Globals | Any table you choose | The VM's own |
| Values | Shared by reference | Copied; functions become proxies |
| Time limit | No | Yes, per call |
| Memory limit | No | Yes |
| Can yield | Yes | Only inside the VM's own coroutines |
| Cost | A table | A whole VM (a few hundred KiB) |

!!! warning

    An environment from `luau.env` controls what code can **reach**, not how long it runs or
    how much memory it takes: `while true do end` still hangs the program. Run untrusted code in
    an isolated VM with a `timeout` and a `memoryLimit`.

A **chunk** is source code (a string) or bytecode made by [`luau.compile`](#luaucompile) (a
buffer). Bytecode isn't verified when it is loaded, and malformed bytecode can crash the
program: only load bytecode you compiled yourself.

**Errors:** misuse (bad arguments, unknown options, a closed VM) raises. `luau.load` returns
`nil` and a message for a syntax error; `vm:try` returns `false` and a [`VMError`](#vmerror);
everything else raises.

## Running code in this VM

### luau.compile

```luau
luau.compile(source: string, options: CompileOptions?): buffer
```

Compiles source code into bytecode, which [`luau.load`](#luauload), [`vm:run`](#vmrun) and
[`vm:load`](#vmload) accept in place of source. Raises on a syntax error.

```luau
type CompileOptions = {
    name: string?,              -- chunk name for error messages (default "chunk")
    optimizationLevel: number?, -- 0, 1 (default) or 2
    debugLevel: number?,        -- 0, 1 (default: line numbers) or 2 (also local names)
}
```

### luau.check

```luau
luau.check(source: string, name: string?): (boolean, string?)
```

Whether the source compiles. If it doesn't, also returns the message, as
`"<name>:<line>: <message>"` (`name` defaults to `"chunk"`).

```luau
luau.check("return +", "input") --> false, "input:1: Expected identifier when parsing expression, got '+'"
```

### luau.load

```luau
luau.load(chunk: string | buffer, options: LoadOptions?): ((...any) -> ...any)?, string?
```

Compiles a chunk into a function. The chunk's arguments are its `...`. On a syntax error,
returns `nil` and the message.

```luau
type LoadOptions = {
    name: string?,              -- chunk name for error messages and stack traces (default "chunk")
    env: { [any]: any }?,       -- the chunk's global table
    optimizationLevel: number?,
    debugLevel: number?,
}
```

`env` is the table the chunk reads and writes its globals in. Without it, the chunk gets a
fresh table that reads through to the caller's globals: it sees everything the caller sees, but
the globals it defines stay in that table.

```luau
local f = luau.load("count = (count or 0) + 1 return count")
print(f(), f()) --> 1   2
print(count)    --> nil

local env = { x = 20 }
luau.load("y = x + 1", { env = env })()
print(env.y)    --> 21
```

### luau.eval

```luau
luau.eval(source: string, env: { [any]: any }?, ...: any): ...any
```

Compiles and runs source code with `...` as its arguments, and returns its results. `env` works
as in [`luau.load`](#luauload). Raises on a syntax error or a runtime error. The code may yield,
for example to wait in a task.

```luau
print(luau.eval("return a + b", { a = 1, b = 2 })) --> 3
print(luau.eval("return select('#', ...)", nil, "x", "y")) --> 2
```

### luau.env

```luau
luau.env(options: EnvOptions?): { [any]: any }
```

A fresh global table with only safe builtins, for `env` in [`luau.load`](#luauload) and
[`luau.eval`](#luaueval):

- the base functions, without `getfenv` and `setfenv` (they can reach the environment of other
  functions on the stack, including yours) and without `require`
- the standard libraries, without `debug` unless you ask for it
- `_G`, pointing at the table itself

Sonata's globals (`sonata`, `args`) aren't included. The libraries are the same read-only
tables your code uses.

```luau
type EnvOptions = {
    libraries: { string }?,     -- which standard libraries to include
    globals: { [string]: any }?, -- extra globals, shared by reference
}
```

```luau
local env = luau.env({ libraries = { "math", "string" }, globals = { width = 80 } })
print(luau.eval("return math.max(width, 100)", env)) --> 100
print(luau.eval("return require", env))             --> nil
```

### luau.libraries

```luau
luau.libraries: { string }
```

The standard libraries a VM or environment can be given, such as `"bit32"`, `"buffer"`,
`"coroutine"`, `"debug"`, `"math"`, `"os"`, `"string"`, `"table"`, `"utf8"` and `"vector"`.
Read-only.

### luau.version

```luau
luau.version: string
```

The version of Luau that Sonata was built with, or `""` if unknown.

## Isolated VMs

### luau.vm

```luau
luau.vm(options: VMOptions?): VM
```

Creates a VM: a separate Luau state with its own globals, its own heap and its own standard
library. Code in it can't see your globals, Sonata's globals or the built-in libraries, only
what you give it.

```luau
type VMOptions = {
    name: string?,               -- chunk name for vm:run / vm:try, and tostring(vm) (default "vm")
    libraries: { string }?,      -- standard libraries (default: all of luau.libraries)
    sandbox: boolean?,           -- default true, see below
    globals: { [string]: any }?, -- copied into the VM's globals
    memoryLimit: number?,        -- bytes; 0 or nil for none
    timeout: number?,            -- seconds per call; 0 or nil for none
    print: ((line: string) -> ()) | false | nil, -- where the VM's print goes (default: stdout)
    modules: { [string]: string }?, -- source code the VM can require by name
    optimizationLevel: number?,
    debugLevel: number?,
}
```

Unknown options raise, and so does a module in `modules` that doesn't compile.

```luau
local output = {}
local vm = luau.vm({
    libraries = { "math", "string", "table" },
    globals = { config = { scale = 2 } },
    print = function(line) table.insert(output, line) end,
    timeout = 0.5,
})
vm:run("print('scaled', 21 * config.scale)")
print(output[1]) --> scaled	42
```

#### Sandboxing

With `sandbox = true` (the default) the standard libraries, the string metatable and the base
globals are read-only, as they are in Sonata's own scripts. The globals chunks define go to a
separate, writable table that lasts as long as the VM, so they carry over from one call to the
next. `_G` refers to that table.

With `sandbox = false`, everything is writable, and chunks can change the libraries.

#### Limits

`timeout` limits how long **each call** into the VM may run: [`vm:run`](#vmrun),
[`vm:call`](#vmcall), calling a function that came out of the VM, and so on. Each call starts
with a fresh budget. When it runs out, the VM raises a timeout error at the next loop
iteration, function call or return, and keeps raising it at every one after that, so code that
catches the error with `pcall` doesn't get far. Time spent in your functions while the VM calls
them counts too.

`memoryLimit` limits the bytes the VM may use in total, its standard library included (about
270 KiB; see [`vm:stats`](#vmstats)). An allocation that would exceed it fails with
`"not enough memory"`, which code in the VM can catch with `pcall`. Once a failed call returns,
the VM collects its garbage, so the next call starts clean.

Neither limit can interrupt a single long-running library call, like a huge `string.rep`
(which the memory limit stops instead) or sorting a very large table.

#### Values crossing between VMs

Every value passed into a VM (arguments, `globals`, `vm:set`) or out of it (results, errors,
`vm:get`) is copied:

- `nil`, booleans, numbers, vectors and strings as they are.
- Buffers are copied byte for byte.
- Tables are copied deeply. Cycles and tables referenced more than once keep their shape;
  frozen tables stay frozen. Metatables aren't copied.
- Functions become **proxies**: calling one runs the original in its own VM, copying the
  arguments in and the results back. A proxy that returns to its original VM turns back into the
  original function, so `vm:get("f") == f` holds for a function `f` you passed in.
- Userdata, threads and other VMs can't cross: passing one raises.

```luau
local vm = luau.vm()
local compare = vm:run("return function(a, b) return a > b end")
local list = { 3, 1, 2 }
table.sort(list, compare) -- the VM's function as an ordinary callback
print(table.concat(list, ",")) --> 3,2,1
```

The functions you give a VM run as if called from a coroutine of your own: if one waits
(`task.wait`, a socket read, ...), the wait happens right there and the other tasks keep running
meanwhile. A function of yours must not yield to the VM; doing so raises an error in the VM.

### VM

A VM is a value of type `LuauVM` (`typeof(vm) == "LuauVM"`).

A **path** names a global (`"config"`) or a field of nested tables (`"config.window.width"`).

#### vm:run

```luau
vm:run(chunk: string | buffer, ...any): ...any
```

Compiles and runs a chunk with `...` as its arguments, and returns its results. Raises on any
failure, with the VM's error message (`"vm:1: attempt to index nil with 'x'"`).

```luau
vm:run("total = 0")
for i = 1, 3 do
    vm:run("total += ...", i)
end
print(vm:run("return total")) --> 6
```

#### vm:try

```luau
vm:try(chunk: string | buffer, ...any): (boolean, ...any)
```

Like [`vm:run`](#vmrun), but never raises for what the chunk does: it returns `true` and the
results, or `false` and a `VMError`.

##### VMError

```luau
type VMError = {
    kind: "syntax" | "runtime" | "timeout" | "memory" | "yield",
    message: string, -- the error message, or a description of a non-string error
    value: any,      -- the error value itself, copied out of the VM
    traceback: string, -- the VM's stack trace ("" for syntax errors)
}
```

| `kind` | Meaning |
|---|---|
| `"syntax"` | The chunk doesn't compile. |
| `"runtime"` | It raised an error (including errors from your functions it called). |
| `"timeout"` | It ran past the time limit. |
| `"memory"` | It ran out of memory. |
| `"yield"` | It yielded outside of a coroutine. |

```luau
local ok, err = vm:try(userCode)
if not ok then
    if err.kind == "timeout" then
        print("your code took too long")
    else
        print(err.message)
    end
end
```

#### vm:load

```luau
vm:load(chunk: string | buffer, name: string?): (...any) -> ...any
```

Compiles a chunk once and returns a function that runs it in the VM each time it is called.
`name` is the chunk name for error messages (default: the VM's name). Raises on a syntax error.

```luau
local step = vm:load("n = (n or 0) + 1 return n", "step")
print(step(), step()) --> 1   2
```

#### vm:call

```luau
vm:call(path: string, ...any): ...any
```

Calls the function at `path` with the arguments and returns its results.

```luau
vm:run("api = { add = function(a, b) return a + b end }")
print(vm:call("api.add", 2, 3)) --> 5
```

#### vm:get

```luau
vm:get(path: string): any
```

The value at `path`, copied out of the VM, or `nil` if it, or a table on the way to it, is
missing.

#### vm:set

```luau
vm:set(path: string, value: any): ()
```

Sets the value at `path`, copied into the VM. Every table on the way must exist. Passing `nil`
removes a global.

```luau
vm:set("settings", { volume = 5 })
vm:set("settings.volume", 7)
```

#### vm:globals

```luau
vm:globals(): { string }
```

The names of the VM's globals, sorted: the ones chunks defined and the builtins.

#### vm:defineModule

```luau
vm:defineModule(name: string, source: string | buffer): ()
```

Adds or replaces a module that code in the VM can `require(name)`, like the `modules` option.
Raises if it doesn't compile. A module runs once, the first time it is required, and must not
require itself in a cycle. A module that returns nothing gives `true`.

```luau
vm:defineModule("vec", "return { len = function(x, y) return math.sqrt(x * x + y * y) end }")
print(vm:run("return require('vec').len(3, 4)")) --> 5
```

#### vm:setTimeout

```luau
vm:setTimeout(seconds: number?): ()
```

Changes the time limit of later calls. `nil` or `0` removes it.

#### vm:setMemoryLimit

```luau
vm:setMemoryLimit(bytes: number?): ()
```

Changes the memory limit. `nil` or `0` removes it.

#### vm:stats

```luau
vm:stats(): VMStats
```

```luau
type VMStats = {
    memory: number,       -- bytes in use
    peakMemory: number,   -- the most bytes in use at once
    memoryLimit: number?, -- when there is a memory limit
    timeout: number?,     -- when there is a time limit
    calls: number,        -- calls into the VM so far
    errors: number,       -- calls that failed
    timeouts: number,     -- calls that ran past the time limit
}
```

#### vm:collect

```luau
vm:collect(): number
```

Runs a full garbage collection in the VM and returns the bytes still in use.

#### vm:reset

```luau
vm:reset(): ()
```

Replaces the VM with a fresh one made from the same options: the globals chunks defined and the
modules already loaded are gone. Functions that came out of the old VM raise when called.
Raises if the VM is running code (from inside one of your functions it called).

#### vm:close

```luau
vm:close(): ()
```

Frees the VM. Every method that runs code raises afterwards, and so do functions that came out
of it. Closing twice is fine. Raises if the VM is running code.

A VM is also freed once nothing refers to it: not the VM value, and no function that came out
of it. One exception: a function of yours that refers to the VM itself, given to that VM, keeps
it alive until `vm:close()` or the end of the program.

```luau
local vm = luau.vm()
vm:set("again", function(code) return vm:run(code) end) -- refers to vm
-- ...
vm:close() -- needed to free it
```

#### vm:isClosed

```luau
vm:isClosed(): boolean
```

Whether [`vm:close`](#vmclose) was called.

## Example: user scripts with limits

```luau
local luau = require("@sonata/luau")

local function runUserScript(source: string, input: { [string]: any })
    local vm = luau.vm({
        libraries = { "math", "string", "table", "utf8" },
        globals = { input = input },
        print = false,
        timeout = 2,
        memoryLimit = 16 * 1024 * 1024,
    })
    local ok, result = vm:try(source)
    vm:close()

    if ok then
        return result
    end
    error(`script failed ({result.kind}): {result.message}`, 0)
end

print(runUserScript("return #input.items * 2", { items = { 1, 2, 3 } })) --> 6
```
