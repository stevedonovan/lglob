local lfs = require 'lfs'
require 'globmod'
print(lfs.currendir())
print(answer())

--~ lglob: plglobal.lua:2: warning: require "globmod" added these globals: message,answer
--~ lglob: plglobal.lua:3: undefined get lfs.currendir
