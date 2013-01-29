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

--~ lglob: new.lua:13: undefined get new.fiddle_factor

