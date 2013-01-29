--- old-fashioned Lua 5.1 module
module('old',package.seeall)

function show ()
    print(answer())
end

function answer ()
    return 42
end
