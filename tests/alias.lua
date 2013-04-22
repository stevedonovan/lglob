local io,table,math = io,table,math

print(io.print)

local function boo()
  return io.print
end

--~ lglob: alias.lua:6: undefined get io.print
