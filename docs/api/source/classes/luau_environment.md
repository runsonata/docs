# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::Environment</code> (Class)

The set of globals to make available to a [`VM`](luau_vm.md). The environment lives on the C++
side; `load()` turns its contents into real Luau globals.

`#include <sonata/core/luau/environment.hpp>`

```cpp
using namespace sonata::luau;

EnvNamespace app;
app.setString("name", "demo")
   .setNumber("build", 42)
   .setFunction("hello", [](VM& vm) -> int {
       lua_pushstring(vm.state(), "hi!");
       return 1;
   });

Environment env;
env.setBoolean("DEBUG", true)
   .setNamespace("app", std::move(app));

VM vm;
env.load(vm);
// Luau: print(app.name, app.build, app.hello(), DEBUG)
```

!!! note

    Function globals see only the VM's main thread; see the warning on
    [`Global`](luau_global.md#kinds). Strings, numbers, booleans, namespaces and custom types
    work everywhere.

`runtime::runProgram` uses an `Environment` to create the [`sonata` global](../../module/globals.md#sonata).

## Definition

```cpp
class Environment {
public:
    using Globals = std::unordered_map<std::string, Global>;

    Environment& set(std::string name, Global global);
    Environment& setFunction(std::string name, Global::Function function);
    Environment& setString(std::string name, std::string value);
    Environment& setNumber(std::string name, double value);
    Environment& setBoolean(std::string name, bool value);
    Environment& setCustom(std::string name, Global::Custom custom);
    Environment& setNamespace(std::string name, EnvNamespace namespace_);
    Environment& setNamespace(std::string name, std::shared_ptr<EnvNamespace> namespace_);

    Global* find(const std::string& name);
    const Global* find(const std::string& name) const;
    bool contains(const std::string& name) const;
    bool remove(const std::string& name);
    void clear();
    bool empty() const noexcept;
    std::size_t size() const noexcept;

    void load(VM& vm) const;
    bool load(VM& vm, const std::string& name) const;

    const Globals& globals() const noexcept;
    Globals& globals() noexcept;
};
```

## Methods

### Setting globals

`set` adds or replaces a [`Global`](luau_global.md). The `set*` helpers do the same for one kind
of value. Every setter returns the environment, so calls chain.

`setNamespace` adds a table of globals: either a copy of an [`EnvNamespace`](#envnamespace), or a
shared one (so several environments can use the same namespace object).

### Looking up and removing

| Method | Description |
|---|---|
| `find(name)` | The stored global, or `nullptr`. |
| `contains(name)` | Whether a global is stored. |
| `remove(name)` | Removes it from the environment. This doesn't remove a global already loaded into a VM. |
| `clear()`, `empty()`, `size()` | |
| `globals()` | The underlying map. |

### `load`

```cpp
void load(VM& vm) const;
bool load(VM& vm, const std::string& name) const;
```

Loads every stored global into the VM, replacing existing globals with the same names. The
second form loads one global, returning `false` if it isn't stored.

Load globals **before** sandboxing the VM (`luaL_sandbox`), which makes them read-only.

## `EnvNamespace`

```cpp
struct EnvNamespace {
    using Members = std::unordered_map<std::string, Global>;
    Members members;

    EnvNamespace& set(std::string name, Global global);
    EnvNamespace& setString(std::string name, std::string value);
    EnvNamespace& setNumber(std::string name, double value);
    EnvNamespace& setBoolean(std::string name, bool value);
    EnvNamespace& setFunction(std::string name, Global::Function function);
    EnvNamespace& setCustom(std::string name, Global::Custom custom);

    Global* find(const std::string& name);
    const Global* find(const std::string& name) const;
    bool remove(const std::string& name);
    bool contains(const std::string& name) const;
    bool empty() const noexcept;
    std::size_t size() const noexcept;
};
```

A table of globals, loaded as a Luau table. A namespace member can itself be a namespace
(`Global` holds a `std::shared_ptr<EnvNamespace>`), so namespaces nest:

```cpp
EnvNamespace project;
project.setString("name", "demo");

EnvNamespace sonata;
sonata.setString("version", "0.1.8");
sonata.set("project", std::make_shared<EnvNamespace>(std::move(project)));
// Luau: sonata.project.name
```

## Loading data files as globals

```cpp
[[nodiscard]] Global toGlobal(const DataValue& value);
[[nodiscard]] EnvNamespace toNamespace(const DataValue& table);
```

Turn a [`DataValue`](luau_datavalue.md) read from a `return { ... }` file into a global, so config
data can be loaded onto a VM as well as read in C++. Nested tables become nested namespaces.

- A `DataValue` never contains a function or custom type, so only the scalar and namespace kinds
  of `Global` are produced.
- `nil` entries are skipped when building a namespace; calling `toGlobal()` on a `nil` value is an
  error.
- Positional entries are exposed under their 1-based index as a **string** key (`"1"`, `"2"`,
  ...), since environments key everything by name.

```cpp
DataValue config = DataFile::parseFile("config.luau");
Environment env;
env.setNamespace("config", toNamespace(config));
env.load(vm);
```
