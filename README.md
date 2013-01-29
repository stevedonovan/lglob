lglob
=====

Extended undefined-variable checker for Lua 5.1 and 5.2

There are various approaches to [detecting undeclared variables](http://lua-users.org/wiki/DetectingUndefinedVariables)
in Lua.  lglob extends the approach used in David Manura's `globalsplus.lua`, which
in turn is an extension of `globals.lua` in the Lua distribution.

The idea is to examine the disassembly listing of the code using `luac` and
track global usage, both setting and getting, and check against a whitelist.
David's approach is to also look at _fields_ of known globals, so that we
can mark `table.Concat` and `math.sine` and so forth as errors.

lglob extends this further to detect writes to known tables, to support Lua 5.2,
and to provide optional local alias analysis.  For help, just type `lglob`; it
understands wilcards on Windows (where the shell doesn't do globbing).

Apart from David's script, this utility was strongly inspired by
Egil Hjelmeland's [globals](https://github.com/hjelmeland/globals) utility, which
I found extremely useful in cleaning up Penlight after the move away from `module`.

Kein-Hong Man's [No Frills Introduction to the Lua VM](http://lua-users.org/lists/lua-l/2006-03/msg00330.html)
has been indispensible for decoding the subtleties of some Lua VM instructions.

## Spellchecking

Even a straightforward Lua script is easy to get wrong. But spelling mistakes
will happen and they are _not_ compile errors.

    -- args.lua
    for i,a in pairs(args) do
        print(i,string.upper(x))
    end

Naturally this becomes a massive
irritation with larger, multi-file programs. People consider this to be the
'price' of using dynamic languages, which is not really true since many errors can be
caught effectively with static bytecode analysis.

    $ lglob args.lua
    lglob: args.lua:2: undefined get args

lglob works with a _whitelist_ of known globals, by default the usual global
environment. It is an effective spellchecker because if a variable is not
declared as a local, it is assumed to be global.

Non-trivial programs often include external libraries, and we would like to track
them as well. The `-l` flag makes lglob load any required modules. Consider this:

    -- use-lfs.lua
    require 'lfs'

    local function getdir ()
        return lfs.currentdir()
    end

    print(getdir())
    print(lfs.changedir('foo'))

    $ lglob -l use-lfs.lula
    lglob: use-lfs.lua:9: undefined get lfs.changedir

This is the output if we leave out the `local` in front of the function:

    lglob: use-lfs.lua:4: undefined set getdir
    lglob: use-lfs.lua:8: undefined get getdir
    lglob: use-lfs.lua:9: undefined get lfs.changedir

lglob by default is strict about the use of globals - it sees both a set and a get
of an unknown global. The `-g` flag makes it accept globals which have been set
in the file. The flag `-t` (for _tolerant_) implies both `-l` and `-g`. Usually you
should strive to use `local` compulsively if you want to write Lua that scales
beyond a dozen-line script, so this easy-going approach is not the default!

lglob is strict about _redefining globals_:

    -- monkey-patch.lua
    function table.concat(t) return t end

    next = 2

    print(table.next)

    $ lglob monkey-patch.lua
    lglob: monkey-patch.lua:2: redefining global table.concat
    lglob: monkey-patch.lua:4: redefining global next
    lglob: monkey-patch.lua:6: undefined get table.next

It often feels convenient to 'monkey-patch' existing functions (and it appears
that the Ruby community have given into the temptation wholesale)
but (again) if you want
to write code that others can understand and which _plays nicely_ with others'
code then you do not want to monkey-patch.  In particular, modules which are
meant to be generally useful should not indulge in monkey business.

## Explicit Whitelisting

It isn't always possible (or desirable) to load required modules, so lglob allows
you to extend the default whitespace (which is the usual global table).

For instance, LuaJava programs have a new global library `luajava` defined. For
this snippet to pass, we need to give lglob an extra whitelist entry:

    -- lj.lua
    print(luajava.bindClass "java.lang.System")

    -- luajava.wlist -- whitelist for using luajava
    luajava = {
        bindClass=true,
        newInstance=true,
        new=true,
        createProxy=true,
        loadLib=true
    }

    $ lglob -w luajava.wlist lj.lua
    (cool)

The whitelist may contain any number of these definitions.

The `-wx` flag works in a similar way, but provides an _exclusive_ whitelist that
overrides the existing one.  In particular, `-wx nil` gives you an empty
whitelist.

Due to the primitive nature of the command-line parser, there can be only one
`-w` or `-wx` flag on a line.

## Local Aliases

There has been a movement away from (ab)using the global namespace in Lua.
A more modern version of the `lfs` example would be:

    -- use-lfs-strictly.lua
    local lfs = require 'lfs'

    local function getdir ()
        return lfs.currentdir()
    end

    print(getdir())
    print(lfs.changedir('foo'))

    $ lglob -x use-lfs-strictly.lua
    lglob: use-lfs-strictly.lua:9: undefined get lfs.changedir

No globals are used, except for the built-in `require` and `print` functions.
This style will also work fine with both Lua 5.1 and 5.2.

The `-x` flag (for extended and/or experimental) tells lglob to track local
_aliases_ for module.  It implies `-l` so the module is loaded, but we don't
assume that the `require` call generates a global.

## Modules

Lua 5.1 introduced a module system based on _function environments_.

    --- old-fashioned Lua 5.1 module
    module('old',package.seeall)

    function show ()
        print(answer())
    end

    function answer ()
        return 42
    end

The `module` call sets the function environment of the module (which is just a
function) to a module table and creates a global 'glob' set to this table;
`require` will also return the table. Any 'global' references are thereafter
to the module table. `package.seeall` injects global references into the module
by giving it a metatable index pointing to `_G`.

lglob tracks the `module` call and sets the `-g` flag, so that the module
functions or fields become known references.

`package.seeall` has got a bad press. In particular, it is a distinct no-no
for any sandboxed application, since the module can be used to refer to
the original global namespace which contains problematic tables like `io` and
`os` which the sandboxer would rather not expose. Also, it is rather inefficient
since any global reference is now indirect.

However, `module` is not intrinsically evil. It remains very convenient, and
without `package.seeall` becomes less problematic.

    --- Better Lua 5.1 module, with a problem
    module(...)

    function show ()
        print(answer())
    end

    function answer ()
        return 42
    end

    $ lglob better.lua
    lglob: better.lua:5: undefined get print

We see that `print` is not visible _after_ `module()`, because it
isn't inside the module environment. lglob's `-gd` (for 'global definitions')
helps here; it prints out the local definitions you need to insert at the
top of your module:

    $ lglob -gd better.lua
    local print = print

Applying to `args.lua` above gives:

    $ lglob -gd args.lua
    local pairs,print = pairs,print
    local string = string

In this way, lglob helps with an irritating part of module creation; the payoff
is worthwhile, since local access is faster than global access and generates
less code.

Personally, the approach I use when writing modules is to keep things simple and
avoid function environment magic - which is depreciated in Lua 5.2 anyway.

    -- new.lua: plain-jane module style for 5.1/5.2 compatibility
    -- tracks both require and module local aliases
    local lfs = require 'lfs'
    local new = {}

    print(lfs.currentdir)

    function new.one ()
        return new.two()
    end

    function new.two ()
        return 42*new.fiddle_factor
    end

    return new

    $ lglob -x new.lua
    lglob: new.lua:13: undefined get new.fiddle_factor

The local aliasing done by `-x` also applies to the _current module_ (since even
the supermen of code have bad days and can't spell their own functions)

By the way, it's still useful to use the output of `-gd` here, since it's useful
documentation (readers can tell at a glance what libraries are used) and often
leads to performance improvements.

## Module Contents and -wl

The `-d` flag dumps all exported contents of a module; the names are set to
their linenumbers, which can be useful, and it is in the right format for
whitelisting.

    $ lglob -d old.lua
    ["old"] = {
        show = 4,
        answer = 8,
    }
    $ lglob -x -d new.lua
    ["new"] = {
        one = 8,
        two = 12,
    }

Note we need to pass `-x` for the 'new-style' module to be analyzed correctly.

The tests directory has a full whitelist for the Penlight library, analysed with
 `lglob -d -x -p pl *.lua`; the `-p` flag ensures that the entries go into the
correct package.

The `pltest.lua` file uses Penlight, but you don't need that library to be
installed to check files that use it. Use the whitelist like so:

    lglob -x -wl penlight.wlist pltest.lua

`-wl` works like `-l` except that no actual code loading takes place; we look
up the module in the special whitelist passed to this flag. (Unlike regular
whitespaces its entries are not available unless there is a corresponding `require`)

## Further Work

No program is ever finished (except perhaps `sed`) and there are some improvements
I have in mind for lglob. I remarked that explicitly using `require` to load
modules can be a problem; if you are working on an embedded system the modules
may not be requirable, and loading a module may have important side-effects.
The `-d`flag is a start in that direction, but how this could be made more
convenient is an open question.

Local analysis remains experimental but has promise. For instance, it would be
most useful to understand common class patterns and track instances of the
special `this` local. Since these patterns are often per-project conventions, this
would be an interesting challenge.
