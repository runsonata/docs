# @sonata/sqlite

SQLite databases, in a file or in memory. SQLite is built into Sonata, so there's nothing to
install, and a built program carries it with it. A program that doesn't use it leaves it out
(about 1 MiB): see [Leaving features out](../../guide/building.md#leaving-features-out).

```luau
local sqlite = require("@sonata/sqlite")

local db = sqlite.open("app.db")
db:exec([[
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        joined TEXT DEFAULT CURRENT_TIMESTAMP
    )
]])

db:run("INSERT INTO users (name) VALUES (?)", { "Ada" })

for _, user in db:query("SELECT id, name FROM users ORDER BY name") do
    print(user.id, user.name)
end

db:close()
```

**Errors:** every function raises on failure, with SQLite's message (`sqlite: UNIQUE constraint
failed: users.name`).

## Values

| SQLite | Luau |
|---|---|
| `INTEGER`, `REAL` | `number` |
| `TEXT` | `string` |
| `BLOB` | `buffer` |
| `NULL` | `nil`: the row has no key for that column |

Parameters bind the other way: whole numbers as `INTEGER` and others as `REAL`, booleans as `1`
and `0`, strings as `TEXT`, buffers as `BLOB`, and `nil` as `NULL`. An integer beyond 2^53 can't be
held exactly by a Luau number, so store larger ones as text.

## Parameters

Values are given in one table: by position for `?` and `?NNN`, and by name (without its prefix)
for `:name`, `@name` and `$name`.

```luau
db:get("SELECT * FROM users WHERE id = ?", { 7 })
db:query("SELECT * FROM users WHERE name LIKE :pattern LIMIT :limit", { pattern = "A%", limit = 10 })
```

A parameter with no value is `NULL`. A value that matches no parameter is an error, so a
misspelled name is caught: `the statement has no parameter :nmae (did you mean :name?)`.

## sqlite.open

```luau
sqlite.open(path: string, options: OpenOptions?): Database
```

Opens the database at `path`, creating the file if it doesn't exist. `":memory:"` is a database
that lives only in memory, and disappears when it's closed.

| Option | Type | Description |
|---|---|---|
| `readOnly` | `boolean?` | Open without the right to write (default `false`). |
| `create` | `boolean?` | Create the file if it doesn't exist (default `true`). |
| `timeout` | `number?` | Seconds to wait for a lock held by another connection before failing with `database is locked` (default 5). |

Calls block until SQLite is done, like file access in [`@sonata/fs`](fs.md): other tasks don't
run meanwhile.

## sqlite.version

```luau
sqlite.version: string
```

The version of SQLite built in, like `"3.54.1"`.

## Database methods

### db:exec

```luau
db:exec(sql: string)
```

Runs every statement in `sql`, without parameters or results: schemas, migrations, pragmas.

### db:query

```luau
db:query(sql: string, params: Params?): { Row }
```

Every row of one statement, each a table of its columns by name.

### db:get

```luau
db:get(sql: string, params: Params?): Row?
```

The first row of one statement, or `nil` if there is none.

### db:run

```luau
db:run(sql: string, params: Params?): { changes: number, lastInsertId: number }
```

Runs one statement that doesn't return rows. `changes` is how many rows it inserted, changed or
deleted, and `lastInsertId` the rowid of the last row this connection inserted.

### db:rows

```luau
db:rows(sql: string, params: Params?): () -> Row?
```

An iterator over the rows of one statement, read one at a time, for results too large to hold at
once.

```luau
for row in db:rows("SELECT * FROM events ORDER BY time") do
    handle(row)
end
```

`query`, `get`, `run` and `rows` take one statement; more than one is an error that points to
`exec`.

### db:prepare

```luau
db:prepare(sql: string): Statement
```

Compiles one statement to run many times, which saves compiling it each time.

### db:transaction

```luau
db:transaction(fn: (db: Database, ...any) -> ...any, ...: any): ...any
```

Runs `fn(db, ...)` in a transaction and returns what it returns. If `fn` raises, everything it
changed is undone and the error is raised again. If committing fails (a deferred constraint),
the changes are undone and that error is raised.

```luau
db:transaction(function()
    db:run("UPDATE accounts SET balance = balance - ? WHERE id = ?", { 100, from })
    db:run("UPDATE accounts SET balance = balance + ? WHERE id = ?", { 100, to })
end)
```

Transactions nest: one inside another is a savepoint, so a failure inside it undoes only its
own changes. `fn` may wait (`task.wait`, a socket), but other tasks using the same database
meanwhile are part of the transaction too.

### db:close

```luau
db:close()
```

Closes the connection. Statements made from it stop working. Closing twice is fine; a database
that's collected is closed for you.

### db:isOpen

```luau
db:isOpen(): boolean
```

## Statement methods

| Method | Description |
|---|---|
| `statement:all(params: Params?): { Row }` | Every row. |
| `statement:get(params: Params?): Row?` | The first row, or `nil`. |
| `statement:run(params: Params?): Result` | Runs it, for statements that don't return rows. |
| `statement:rows(params: Params?): () -> Row?` | An iterator over the rows. Starting it again restarts the statement. |
| `statement:columns(): { string }` | The names of the columns it returns. |
| `statement:close()` | Frees it now instead of when it's collected. Closing twice is fine. |

```luau
local insert = db:prepare("INSERT INTO points (x, y) VALUES (?, ?)")
db:transaction(function()
    for _, point in points do
        insert:run({ point.x, point.y })
    end
end)
```

## What's built in

SQLite is compiled with full-text search ([FTS5](https://sqlite.org/fts5.html)), the
[math functions](https://sqlite.org/lang_mathfunc.html), and JSON functions. Loading extensions
isn't possible: Sonata is one static executable.
