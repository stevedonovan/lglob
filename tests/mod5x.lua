local print = print
local M = {}
_LGLOB=nil
function M.say(msg)
    print(tostring(msg))
end
return M

--~ lglob: mod5x.lua:5: undefined get tostring
