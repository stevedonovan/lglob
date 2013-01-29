-- use-lfs.lua
require 'lfs'

function getdir ()
    return lfs.currentdir()
end

print(getdir())
print(lfs.changedir('foo'))
