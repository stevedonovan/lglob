-- flags:
-- This program passes strict mode because all globals are known, but not with -wx nil

for i,a in pairs(arg) do
    print(i,string.upper(a))
end

--~ lglob: fine.lua:4: undefined get pairs
--~ lglob: fine.lua:4: undefined get arg
--~ lglob: fine.lua:5: undefined get string
--~ lglob: fine.lua:5: undefined get print
--~ lglob: fine.lua:5: undefined get string.upper
