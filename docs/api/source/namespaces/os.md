# <code><a href="../sonata">sonata</a>::os</code> (namespace)

Small OS helpers shared by the package manager, `sn build` and the runtime.

`#include <sonata/core/system.hpp>`

## `EnvList`

```cpp
using EnvList = std::vector<std::pair<std::string, std::string>>;
```

## `ProcessResult`

```cpp
struct ProcessResult {
    bool started = false; // false if the executable couldn't be launched at all
    int exitCode = -1;
    std::string output;   // stdout and stderr, interleaved (the last 64 KiB)
};
```

## `runProcess`

```cpp
ProcessResult runProcess(const std::vector<std::string>& args, const EnvList& env = {},
                         bool inheritOutput = false);
```

Runs `args[0]` (looked up on `PATH`) with the given arguments and waits for it. No shell is
involved, so nothing in an argument can be read as shell syntax. stdin is the null device. `env`
adds to or overrides the current environment.

Output is captured into `ProcessResult::output`, unless `inheritOutput` is true: then the child
writes straight to this process's stdout/stderr and `output` stays empty.

```cpp
auto result = sonata::os::runProcess({"git", "--version"}, {{"GIT_TERMINAL_PROMPT", "0"}});
if (!result.started)
    std::cerr << "git is not installed\n";
else if (result.exitCode == 0)
    std::cout << result.output;
```

## `executablePath`

```cpp
std::optional<std::filesystem::path> executablePath();
```

The running executable's own path, or `std::nullopt` if the OS won't say.

## `homeDirectory`

```cpp
std::optional<std::filesystem::path> homeDirectory();
```

`$HOME`, or `%USERPROFILE%` on Windows. `std::nullopt` if neither is set.
