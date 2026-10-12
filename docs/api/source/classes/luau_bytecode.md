# <code><a href="../../namespaces/sonata">sonata</a>::<a href="../../namespaces/luau">luau</a>::Bytecode</code> (Class)

Compiled, execution-ready Luau: the bytes produced by [`Compiler`](luau_compiler.md) and
loaded by [`VM::execute`](luau_vm.md) or `luau_load`.

`#include <sonata/core/luau/compiler.hpp>`

## Definition

```cpp
class Bytecode {
public:
    using Byte = std::uint8_t;

    Bytecode() = default;
    Bytecode(const void* data, std::size_t size);
    explicit Bytecode(const std::string& data);
    explicit Bytecode(std::vector<Byte> data);

    const Byte* data() const noexcept;
    Byte* data() noexcept;
    std::size_t size() const noexcept;
    bool empty() const noexcept;
    const char* luauData() const noexcept;

    bool save(const std::filesystem::path& path) const;
    static Bytecode load(const std::filesystem::path& path);

    const std::vector<Byte>& bytes() const noexcept;
    std::vector<Byte>& bytes() noexcept;

    std::optional<std::string> compileError() const;
};
```

## Constructors

| Constructor | Description |
|---|---|
| `Bytecode()` | Empty. |
| `Bytecode(const void* data, std::size_t size)` | Copies raw bytes. |
| `Bytecode(const std::string& data)` | From Luau's `std::string` output (`Luau::compile`). |
| `Bytecode(std::vector<Byte> data)` | Takes ownership of a byte vector. |

## Methods

| Method | Description |
|---|---|
| `data()`, `size()`, `empty()` | Access to the bytes. |
| `luauData()` | The bytes as `const char*`, for Luau's C API (`luau_load`). |
| `bytes()` | The underlying `std::vector<Byte>`. |
| `save(path)` | Writes the bytes to a file. Returns `false` on failure. |
| `load(path)` | Reads bytes from a file. Throws `std::runtime_error` on failure. |
| `compileError()` | See below. |

### `compileError`

```cpp
std::optional<std::string> compileError() const;
```

Luau reports a compile error as "bytecode" that fails to load with the message
(`":<line>: <message>"`). This returns that message, or `std::nullopt` for real bytecode.
[`Compiler::compile`](luau_compiler.md#compile) never throws for bad source, so always check:

```cpp
sonata::luau::Bytecode code = compiler.compile(source);
if (auto error = code.compileError()) {
    std::cerr << "main.luau" << *error << '\n'; // main.luau:3: Expected 'end' ...
    return;
}
```
