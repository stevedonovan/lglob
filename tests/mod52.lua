local print = print
_ENV={}
function say(msg)
    print(tostring(msg))
end
return _ENV

--~ lglob: mod52.lua:4: undefined get tostring
