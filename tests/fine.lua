-- flags:
-- This program passes strict mode because all globals are known, but not with -wx nil

for i,a in pairs(arg) do
    print(i,string.upper(a))
end

--~ globals: fine.lua:4: undefined get pairs
--~ globals: fine.lua:4: undefined get arg
--~ globals: fine.lua:5: undefined get string
--~ globals: fine.lua:5: undefined get print
--~ globals: fine.lua:5: undefined get string.upper
