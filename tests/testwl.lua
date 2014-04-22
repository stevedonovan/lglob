local lfs = require 'lfs'
local lpeg = require 'lpeg'
print(lfs.currentdir())
print(lpeg.G)

--~ lglob: testwl.lua:4: undefined get lpeg.G
