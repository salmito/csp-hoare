local clp=require'clp'
local io=require'io'
local t=getmetatable(clp.channel())
local select=select
local unpack=unpack or require'table'.unpack
 
local f=function(c) return c:get() end
 
t.safeget=function (c)
    local r={pcall(f,c)}
    if r[1]==true then
      return select(2,unpack(r))
    end
    return nil
end
local safeget=t.safeget
t.range=function(self)
    return safeget, self
end

if not (...) then
  local c=clp.channel(5)
  clp.process(function()
      for i=1,10 do 
        c:put(i) 
      end
      c:close()
  end)()
  
  for i in c:range() do
    print(i)
  end
end
