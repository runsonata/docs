# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/lib">lib</a>::LibraryRegistry</code> (Class)

The set of built-in libraries a [`ModuleLoader`](luau_moduleloader.md) can serve.

`#include <sonata/core/library.hpp>`

## Definition

```cpp
class LibraryRegistry {
public:
    void add(NativeLibrary library);
    const NativeLibrary* find(std::string_view name) const;
    std::vector<std::string> names() const;
};
```

Every `ModuleLoader` owns one, filled by
[`registerBuiltinLibraries`](../namespaces/lib.md#registerbuiltinlibraries) when it is
constructed. Extra libraries are added with
[`ModuleLoader::addLibrary`](luau_moduleloader.md#addlibrary).

## Methods

### `add`

```cpp
void add(NativeLibrary library);
```

Registers a library. Throws `std::invalid_argument` for a bad name (only lowercase letters,
digits, `_` and `-` are allowed), a missing opener, or a name that is already taken.

### `find`

```cpp
const NativeLibrary* find(std::string_view name) const;
```

The library called `name` (without the `@sonata/` prefix), or `nullptr`.

### `names`

```cpp
std::vector<std::string> names() const;
```

Every registered name, sorted. Used for error messages.

## Example

```cpp
sonata::lib::LibraryRegistry registry;
sonata::lib::registerBuiltinLibraries(registry);

for (const std::string& name : registry.names())
    std::cout << "@sonata/" << name << '\n';
```
