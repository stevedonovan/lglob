local lua = arg[-1]
local luac = arg[1]
local lua52 = _VERSION:match '5%.2$'

local cases = {
    {'altering-globals.lua','',false},
    {'fine.lua','',true},
    {'tolerant.lua','-t',true,true},
    {'fine.lua','-wx nil',false},
    {'lj.lua','-w luajava.wlist',true},
    {'localrequire.lua','',false},
    {'new.lua','',false},
    {'pltest.lua','-wl penlight.wlist',true},
    {'TestGlobal.lua','',true},
    {'alias.lua','',false},
    {'lhs.lua','',false},
}

for _,case in ipairs(cases) do
    local file, flags, passed = case[1],case[2],case[3]
    if case[4] == nil or case[4]==lua52 then
        if luac then flags = flags .. ' -luac '..luac end
        local cmd = lua..' ../lglob '..flags..' '..file
        print(cmd)
        local f = io.popen(cmd..' 2>&1')
        local res = f:read '*a'
        -- problem if we got output and did not expect it!
        if passed and res ~= '' then
            print('case ',file,' failed\n',res)
        end
        if not passed then
            local ff = io.open(file,'r')
            -- grab the expected result from appropriate comments
            local testr = {}
            for line in ff:lines() do
                local x = line:match '%-%-~ (.+)'
                if x then table.insert(testr,x) end
            end
            -- which we expect to match!
            testr = table.concat(testr,'\n')..'\n'
            if testr ~= res then
                print('case ',file,' did not fail properly!\n')
                print('+'..testr)
                print('-'..res)
            end
        end
        f:close()
    end
end
