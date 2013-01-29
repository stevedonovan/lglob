-- flags:
-- testing detection of altering global tables
-- plus regression for Jorge problem

function table.concat(t) return t end

next = 2

local opts={}
if opts["h"] then
    os.exit ()
end
if not opts["gogo"] then
end

print(table.next)

--~ lglob: altering-globals.lua:5: redefining global table.concat
--~ lglob: altering-globals.lua:7: redefining global next
--~ lglob: altering-globals.lua:16: undefined get table.next
