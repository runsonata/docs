# <code><a href="../sonata">sonata</a>::doctor</code> (namespace)

The checks behind [`sn doctor`](../../../guide/doctor.md). It's part of the command line, not of
the core.

`#include <sonata/cli/doctor/doctor.hpp>`

## Adding a check

A check is a plain value in one of three lists, one per area. To add one, write a function that
returns what it found, and append it to the list in `doctor/installation.cpp`, `environment.cpp`
or `project.cpp`:

```cpp
std::vector<Finding> checkGit(Context& context) {
    const os::ProcessResult result = os::runProcess({"git", "--version"});
    if (result.started && result.exitCode == 0) {
        return {ok(result.output)};
    }
    return {info("Git isn't installed; it's only needed for packages")};
}

void addEnvironmentChecks(Checks& checks) {
    const auto add = [&](std::string id, auto run) { checks.push_back({std::move(id), Category::Environment, run}); };

    add("env.git", checkGit);
}
```

That's all: the runner handles printing, JSON, `--fix` and exceptions. A check that throws becomes
an error finding.

Only attach a [`Fix`](#fix) if it's safe to apply without asking, because `--fix` doesn't ask, and
never touch the user's code.

A built-in library can add its own check without touching this folder: see
[`NativeLibrary::selfCheck`](lib.md#selfcheckresult).

## Types

### `Finding`

```cpp
enum class Severity { Ok, Info, Skipped, Warning, Error };

struct Finding {
    Severity severity = Severity::Ok;
    std::string summary;              // one line saying what was found
    std::vector<std::string> details; // more lines, shown under it
    std::string hint;                 // what to do about it
    std::optional<Fix> fix;
};
```

`ok(summary)`, `info(summary)`, `skipped(summary)`, `warning(summary, hint)` and
`error(summary, hint)` make one of each.

### `Fix`

```cpp
struct Fix {
    std::string description;
    std::function<void()> apply; // throws on failure
};
```

### `Context`

```cpp
struct Context {
    std::filesystem::path start;                     // where to look for a project
    std::optional<std::filesystem::path> executable; // this sn
    std::optional<std::filesystem::path> projectRoot;
    std::optional<Project> project; // set if the manifest could be read
    std::string projectError;       // why it couldn't, if there is a project
};
```

What every check can look at. `makeContext(start)` builds one.

### `Check`

```cpp
enum class Category { Installation, Environment, Project };

struct Check {
    std::string id; // "install.path"
    Category category;
    std::function<std::vector<Finding>(Context&)> run;
};

using Checks = std::vector<Check>;
```

## Running the checks

```cpp
struct RunOptions {
    std::optional<Category> only;
    bool applyFixes = false;
    std::function<void(const Entry&)> onEntry; // called as results come in
};

Report runChecks(Context& context, const RunOptions& options);
```

`Report::entries` holds every result, as an `Entry` with its `check`, `category`, `finding` and
whether it was `fixed`. `Report::count(severity)` counts them.
