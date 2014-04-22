lglob
=====

Extended undefined-variable checker for Lua 5.1 and 5.2

There are various approaches to [detecting undeclared variables](http://lua-users.org/wiki/DetectingUndefinedVariables)
in Lua.  lglob extends the approach used in David Manura's `globalsplus.lua`, which
in turn is an extension of `globals.lua` in the Lua distribution.

The idea is to examine the disassembly listing of the code using `luac` and
track global usage, both setting and getting, and check against a whitelist.
David's approach is to also look at _fields_ of known globals, so that we
can mark `table.Concat` and `math.sine` as errors.

lglob extends this further to detect writes to known tables, to support Lua 5.2,
and to provide optional local alias analysis.  For help, just type `lglob`; it
understands wilcards on Windows (where the shell doesn't do globbing).

Apart from David's script, this utility was strongly inspired by
Egil Hjelmeland's [globals](https://github.com/hjelmeland/globals) utility, which
I found extremely useful in cleaning up Penlight after the move away from `module`.

Kein-Hong Man's [No Frills Introduction to the Lua VM](http://luaforge.net/docman/83/98/ANoFrillsIntroToLua51VMInstructions.pdf)
has been indispensible for decoding the subtleties of some Lua VM instructions.

## Spellchecking

Even a straightforward Lua script is easy to get wrong. But spelling mistakes
will happen and they are _not_ compile errors.

```Lua
-- args.lua
for i,a in pairs(args) do
    print(i,string.upper(x))
end
```

Naturally this becomes a massive
irritation with larger, multi-file programs. People consider this to be the
'price' of using dynamic languages, which is not really true since many errors can be
caught effectively with static bytecode analysis.

```Lua
$ lglob args.lua
lglob: args.lua:2: undefined get args
```

lglob works with a _whitelist_ of known globals, by default the usual global
environment. It is an effective spellchecker because if a variable is not
declared as a local, it is assumed to be global.

Non-trivial programs often include external libraries, and we would like to track
them as well. By default lglob tries to load any required modules. Consider this:

```Lua
-- use-lfs.lua
require 'lfs'

local function getdir ()
    return lfs.currentdir()
end

print(getdir())
print(lfs.changedir('foo'))

$ lglob use-lfs.lula
lglob: use-lfs.lua:9: undefined get lfs.changedir
```

This is the output if we leave out the `local` in front of the function:

    lglob: use-lfs.lua:4: undefined set getdir
    lglob: use-lfs.lua:8: undefined get getdir
    lglob: use-lfs.lua:9: undefined get lfs.changedir

lglob by default is strict about the use of globals - it sees both a set and a get
of an unknown global. The `-g` flag makes it accept globals which have been set
in the file; the flag `-t` for _tolerant_ is an alias. Usually you
should strive to use `local` compulsively if you want to write Lua that scales
beyond a dozen-line script, so this easy-going approach is not the default!

lglob is strict about _redefining globals_:

```Lua
-- monkey-patch.lua
function table.concat(t) return t end

next = 2

print(table.next)

$ lglob monkey-patch.lua
lglob: monkey-patch.lua:2: redefining global table.concat
lglob: monkey-patch.lua:4: redefining global next
lglob: monkey-patch.lua:6: undefined get table.next
```

It often feels convenient to 'monkey-patch' existing functions (and it appears
that the Ruby community have given into the temptation wholesale)
but (again) if you want
to write code that others can understand and which _plays nicely_ with others'
code then you do not want to monkey-patch.  In particular, modules which are
meant to be generally useful should not indulge in monkey business.

## Explicit Whitelisting

LuaJava programs have a new global library `luajava` defined. For
this snippet to pass, we need to give lglob an extra whitelist entry:

```Lua
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
```

The whitelist may contain any number of these definitions, in plain Lua style
(functions may be defined on the top level as well)

If the special file `global.whitelist` exists in the same directory as lglob invocation,
then this is pulled in with an implicit `-w`.

When dealing with a custom Lua environment, not all of the usual globals may be available.
There are two ways to handle this. The `-wx` flag works in a similar way to `-w`,
but provides an _exclusive_ whitelist that overrides the existing one.  Or you can define
a _blacklist_ in the same format and use `-b` to _remove_ entries from the default whitelist.

```Lua
-- restricted.wlist
debug = true
setmetatable = true
setfenv = true
```

It isn't always possible or desirable to load required modules using `require`. The whitelist
loaded by `-wl` is _only_ used to resolve modules.  So if we had two modules 'boo' and 'bar, then:

```Lua
-- boobar.wlist
boo = {
    open = true,
    close = true
}
foo = {
    print = true,
    query = true
}

-- useboobar.lua
require 'boo'  -- either way works --
local foo = require 'foo'

local b = boo.open 'mine'
foo.print(b)
boo.close(b)

$ lglob -wl boobar.wlist
(cool)
```

If any 'module whitelists' are supplied, then lglob will not try to resolve modules by calling `require`
directly. If you don't wish to track requires, then `-wl nil` will define an empty whitelist.


## Local Aliases

There has been a movement away from (ab)using the global namespace in Lua.
A more modern version of the `lfs` example would be:

```Lua
-- use-lfs-strictly.lua
local lfs = require 'lfs'

local function getdir ()
    return lfs.currentdir()
end

print(getdir())
print(lfs.changedir('foo'))

$ lglob -x use-lfs-strictly.lua
lglob: use-lfs-strictly.lua:9: undefined get lfs.changedir
```

No globals are used, except for the built-in `require` and `print` functions.
This style will also work fine with both Lua 5.1 and 5.2.

In this case lglob will track `lfs` as an _alias_ for the module; if you called it `L`
it would work as well.

## Modules

Lua 5.1 introduced a module system based on _function environments_.

```Lua
--- old-fashioned Lua 5.1 module
module('old',package.seeall)

function show ()
    print(answer())
end

function answer ()
    return 42
end
```

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

```Lua
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
```

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

This release also deals with the `_ENV` Lua 5.2 idiom which achieves the same result:

```Lua
local print = print
_ENV={}
function say(msg)
    print(tostring(msg))
end
return _ENV
--> lglob: mod52.lua:4: undefined get tostring
```

Personally, the approach I use when writing modules is to keep things simple and
avoid function environment magic - which is deprecated in Lua 5.2 anyway.

```Lua
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
```

The local aliasing tracked by ldoc also applies to the _current module_ (since even
the supermen of code have bad days and can't spell their own functions)

By the way, it's still useful to use the output of `-gd` here, since it's useful
documentation (readers can tell at a glance what libraries are used) and often
leads to performance improvements.

If you are a really careful coder (verging on the paranoid) then lglob provides a portable way
to indicate that the global namespace is not available. The special global `_LGLOB` has the
same static effect as `_ENV`, although it has no run-time meaning and just acts as a marker.

```Lua
local print = print
local M = {}
_LGLOB=nil
function M.say(msg)
    print(tostring(msg))
end
return M
--> lglob: mod5x.lua:5: undefined get tostring
```

Obviously lglob cannot deal with any dynamic modification of the environment, such as using `setmetatable`.


## Generating Whitelists from Module Contents and requires

The `-d` flag dumps all exported contents of a module; the names are set to
their linenumbers, which can be useful, and it is in the right format for
whitelisting.

```Lua
$ lglob -d old.lua
["old"] = {
    show = 4,
    answer = 8,
}
$ lglob -d new.lua
["new"] = {
    one = 8,
    two = 12,
}
```

The `-dx` flag applies to a full lglob invocation and captures all the 'exceptions', which
you have deemed harmless:

```
~/lua/Penlight/lua$ lglob -dx . > global.whitelist
.....
~/lua/Penlight/lua$ cat global.whitelist
_G["debug.upvaluejoin"] = true
_G["lapp.slack"] = true
_G["utils.pack"] = true
```

The tests directory has a full whitelist for the Penlight library, analysed with
 `lglob -d -p pl *.lua`; the `-p` flag ensures that the entries go into the
correct package.

The `pltest.lua` file uses Penlight, but you don't need that library to be
installed to check files that use it. Use the whitelist like so:

    lglob -wl penlight.wlist pltest.lua

The `-rd` flag has a similar output but dumps all _required_ modules. For instance, `basic.wlist`
in the `tests` directory is made with `lglob -rd req.lua > basic.wlist`.

```Lua
-- req.lua
require 'lfs'
require 'socket'
require 'socket.http'
require 'socket.ftp'
require 'socket.smtp'
require 'lpeg'
```

## Further Work

No program is ever finished (except perhaps `sed`) and there are some improvements
I have in mind for lglob.

A surprisingly tricky problem which is (partially) solved in this
release is the common use of local aliases for globals in modules:

```Lua
local T = table

print(T.concatenate {1,2,3})
```

Although not perfect, lglob will flag issues like this.

Some Lua 5.2 users already use `_ENV` to create local environments on a per-block basis,
but lglob does not currently support this.  If someone can convince me that this is more
than a fad, I will be happy to try implement these extended patterns ;)

Local analysis remains experimental but has promise. For instance, it would be
most useful to understand common class patterns and track instances of the
special `self` local. Since these patterns are often per-project conventions, this
would be an interesting challenge.
