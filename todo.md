# Todo

## Overall

* ~~Split into more files~~
* Actually learn crystal
  * Surely I don't need to `.as(Whatever)` right after a `.is_a?(Whatever)`
  * `loop do` but for `{ Statement* }` kind of structures

## Tokenizing

* Comments(!)
* Directives
* Continuation sections (these made it to v2? for real?)
* Floats
* `#Include`
* Single quote strings
* Escapes in strings

## Parsing

* Control flow
  * ~~`loop`~~
    * ~~`until`~~
    * `loop parse`
  * ~~`continue`~~
  * ~~`break`~~
  * ~~`while`~~
  * `for` (related: enumerators)
  * `switch`
  * Exceptions
    * Throw
    * Try
    * Catch
  * Goto
    * labels
* `class`
  * `extends`
  * `static`
* Hotkeys
* Hotstrings
* Expressions
  * Implicit concatenation
  * Variadic calls
  * Implicit function call statements (`MsgBox "AAAA"`)
  * Floats
* Functions
  * Variadic definitions (anonymous and regular)
  * Parameters with default values
* ByRef parameters (do these still exist?)
* Floating blocks
* Directives
* `global`-s
* Errors
  * For the top level "parse_statement", we should remember why the input failed to be parsed as the various ambiguous structures, and report them all, instead of just showing the expression parser error.

## Evaluating

* Control flow
  * ~~`loop`~~
    * ~~`until`~~
    * `loop parse`
  * ~~`continue`~~
  * ~~`break`~~
  * ~~`while`~~
  * `for` (related: enumerators)
  * ~~`if`~~
  * `switch`
    * Labels in cases?
    * Goto between cases?
    * Why does `goto` still exist?!
  * Exceptions
    * Throw
    * Try
    * Catch
* Functions
  * Variadic (anonymous and regular)
  * ByRef parameters (do these still exist?)
  * Parameters with default values
* OOP
  * Dynamic properties
  * Inheritance
  * Methods
    * `this` parameter
    * `super`
  * Prototypes
  * `__Item` property
  * `is`/types
* Scope
  * Substitution
    * Including a.%b%, where we don't resolve to a variable
  * `VarRef`-s
  * `global`-s
* Array literals
* Most operators
* Directives
* Floats
* Maps
* `Array()`/`Map()` constructor functions

## Built in functions

* Oh my god, all of them
