local clp=require'clp'
local csp=require'csp'
--clp.pool:add(10)
require'range'

local function testEqual(result,expected)
  if result~=expected then
    error('wrong result: '..tostring(result))
  end
end

--test copy
print('starting tests',csp.copy)

local function test_east_west(task,input,expected) 
	local west, east = clp.channel(),clp.channel()
	clp.process(function()
		local string=require'string'
		for c in string.gmatch(input,".") do
			west:put(c)
		end
    west:close()
	end)()
	task(west,east)
  
  local r={}
  for s in east:range() do
    table.insert(r,s)
  end
  local result=require'table'.concat(r)
  testEqual(result,expected)
  return 'passed'
end

local function test_disassemble(task,input,expected) 
  local east = clp.channel()
	task(input,east)
  local r={}  
  for s in east:range() do    
    table.insert(r,s)
  end
  local result=table.concat(r)
  testEqual(result,expected)
  return 'passed'
end

local function test_assemble(task,input,expected) 
  local X,lineprinter = clp.channel(),clp.channel()
	task(X,lineprinter)
  local r={}
  for _,i in ipairs(input) do
    for c in string.gmatch(i,".") do
      X:put(c)
    end
  end
  X:close()
  for s in lineprinter:range() do
    table.insert(r,s)
  end
  testEqual(r[1],expected[1])
  testEqual(r[2],expected[2])
  return 'passed'
end

local function test_reformat(task,input,expected) 
  local lineprinter = clp.channel()
  
	task(input,lineprinter)
  local r={}
  for s in lineprinter:range() do
    table.insert(r,s)
  end
  testEqual(r[1],expected[1])
  testEqual(r[2],expected[2])
  return 'passed'
end

print('3 - Coroutines')

print('3.1 - COPY\t',
    test_east_west(csp.copy(), "Hello ** World***", "Hello ** World***"))


print('3.2 - SQUASH\t',
  test_east_west(csp.squash(), "Hello ** World***", "Hello ↑ World↑*"))


print('3.3 - DISASSEMBLE',
  test_disassemble(csp.disassemble(), {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}, 
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb "
))

print('3.4 - ASSEMBLE\t',
  test_assemble(csp.assemble(), {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}, 
    {"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
     "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                                                                                          "}
))

print('3.4 - REFORMAT\t',
  test_reformat(csp.reformat(), {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}, 
    {"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
     "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                                                                                         "}
))

print('3.5 - CONWAY\t',
  test_reformat(csp.conway(), {
      "**aa*aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 
      "b**bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb*b*"}, 
    {"↑aa*aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa b↑bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
     "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb*b*                                                                                       "}
))

print()
print('4 - Subroutines and Data Representations')

local res=csp.fac(16)
res:put(16)
print('4.1 - Factorial\t',res:get()==20922789888000 and "passed" or "failed")



local set=csp.intset(6) -- up to 6 integers
set.insert(10) set.insert(42) set.insert(3) set.insert(21) set.insert(98)
set.insert(10)
set.insert(10)
set.insert(10)
set.insert(10)
set.insert(10)
set.insert(10)
set.insert(10)
set.insert(10)
set.insert(10)
print('4.2 - Intset\t',
   assert(set.has(10)==true) and assert(set.has(9)==false) and assert(set.has(42)==true) and "passed" or "failed")