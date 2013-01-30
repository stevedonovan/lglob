local someComponents = {}
local anURL = 'http://lua.org/'

anURL = anURL:gsub( '#(.*)$', function( aValue )
    someComponents.type = nil
    someComponents.fragment = aValue
    return ''
end )
