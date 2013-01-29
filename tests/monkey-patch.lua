-- monkey-patch.lua
function table.concat(t) return t end

next = 2

print(table.next)
