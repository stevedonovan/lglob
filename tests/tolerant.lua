-- flags: -t (only Lua 5.1)
-- tolerant mode
-- - loads any require'd modules
-- - accounts for any global definitions within the file

require 'lfs'

function getdir ()
    return lfs.currentdir()
end

print(getdir())

