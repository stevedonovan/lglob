-- modern practice is to always alias modules with a module,
-- even if they do happen to return a global
local a; local lfs = require 'lfs'
local socket = require 'socket'

print(lfs.curdir)
print(lfs.currentdir())

local function curr (x)
    return lfs.changedir()
end

print(socket.connect,socket.open)

--~ globals: localrequire.lua:6: undefined get lfs.curdir
--~ globals: localrequire.lua:10: undefined get lfs.changedir
--~ globals: localrequire.lua:13: undefined get socket.open



