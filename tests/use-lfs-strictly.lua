-- use-lfs-strictly.lua
local lfs = require 'lfs'

local function getdir ()
    return lfs.currentdir()
end

print(getdir())
print(lfs.changedir('foo'))
