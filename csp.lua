--[[
The examples from Tony Hoare's 1978 paper "Communicating
sequential processes" implemented in CLP.

http://www.cs.ucf.edu/courses/cop4020/sum2009/CSP-hoare.pdf

Requires Lua version >= 5.2 or luajit (won't work with Lua 5.1 because
of the 'yield from metamethod/C function' error
--]]

local clp=require'clp'
local csp={}

--- 
-- Section 3.1 - Copy
-- Problem: Write a process X to copy characters output by 
-- process west to process, east. 
--
-- Solution: 
-- X :: *[c:character; west?c --> east!c] 

csp.copy=function() return clp.process(
  function(west,east)
    require'range'
		for char in west:range() do
			east:put(char)
		end

		east:close()
	end)
end

--- 
-- Section 3.2 - Squash
-- Problem: Adapt the previous program to replace every 
-- pair of consecutive asterisks "**" by an upward arrow 
-- "↑". Assume that the final character input is not an 
-- asterisk. 
--
-- Solution: 
-- X :: *[c:character; west?c -->
--    [c ~= asterisk --> east!c 
--    [c == asterisk --> west?c; 
--      [c ~= asterisk --> east!asterisk; east!c 
--      [c == asterisk --> east!upward arrow 
-- ]]] 

csp.squash=function()
  return clp.process(function(west,east)
    require'range'
		for char in west:range() do
      if char~='*' then 
        east:put(char) 
      else 
        local char2=west:safeget()
        if not char2 then east:put'*' break end
        if char2=='*' then
          local string=require'string'
          east:put(string.char(226))
          east:put(string.char(134))
          east:put(string.char(145))
        else
          east:put'*'
          east:put(char2)
        end
      end
		end
		east:close()
	end)
end

--- 
-- Section 3.3 - Disassemble
-- Problem: to read cards from a cardfile and output to 
-- process X the stream of characters they contain. An extra 
-- space should be inserted at the end of each card. 
--
-- Solution: 
--  *[cardimage:(l..80)character; cardfile?cardimage -->
--      i:integer; i = 1; 
--      *[i <= 80 --> X!cardimage(i); i = i + 1] 
--      X!space 
--  ] 
csp.disassemble=function()
  return clp.process(function(cardfile,X)
    for _,cardimage in ipairs(cardfile) do
      for c in require'string'.gmatch(cardimage,".") do
        X:put(c)
      end
      X:put' '
    end
    X:close()
  end)
end

---
-- Section 3.4 - Assemble
--
-- Problem: To read a stream of characters from process X
-- and print them in lines of 125 characters on a lineprinter. 
-- The last line should be completed with spaces if necessary.
--
-- Solution: 
-- lineimage:(1.. 125)character; 
-- i:integer; i = 1; 
-- * [c:character; X?c 
--      lineimage(i) = c; 
--      [i <= 124 --> i = i + 1
--      [i = 125 --> lineprinter!lineimage; i = 1 
--      ]]; 
-- [i = 1 --> skip 
-- [i > 1 --> *[i <= 125 --> lineimage(i) = space; i = i + 1]; 
--     lineprinter!lineimage 
-- ] 
--
-- Note: (I) When X terminates, so will the first repetitive 
-- command of this process. The last line will then be 
-- printed, if it has any characters. 
csp.assemble=function()
  return clp.process(function(X,lineprinter)
    local table=require'table'
    require'range'
    local linelen=125
    local lineimage={}
    local i=1 --next position
    for char in X:range() do
        lineimage[i]=char
        i=i+1
        if i>linelen then
          lineprinter:put(table.concat(lineimage))
          i=1
        end
    end
    -- Print the last line padded with spaces.
    if i>1 then
      for j=i,linelen do
        lineimage[j]=' '
      end
      lineprinter:put(table.concat(lineimage))
    end
    lineprinter:close()
  end)
end

---
-- Section 3.5 - Reformat
--
-- Problem: Read a sequence of cards of 80 characters each, 
-- and print the characters on a lineprinter at 125 characters 
-- per line. Every card should be followed by an extra 
-- space, and the last line should be completed with spaces 
-- if necessary. 
-- Solution: 
-- [west::DISASSEMBLE || X::COPY || east::ASSEMBLE] 
csp.reformat=function()
  return clp.process(function(cardfile,lineprinter)
      local pipe=clp.channel()
      csp.disassemble()(cardfile,pipe)
      csp.assemble()(pipe,lineprinter)
  end)
end


--- Section 3.6 - Conway's Problem
-- Problem: Adapt the above program to replace every pair 
-- of consecutive asterisks by an upward arrow. 
-- Solution: 
--[west::DISASSEMBLE || X::SQUASH || east::ASSEMBLE] 
csp.conway=function()
  return clp.process(function(cardfile,lineprinter)
      local pipe1,pipe2=clp.channel(),clp.channel()
      csp.disassemble()(cardfile,pipe1)
      csp.squash()(pipe1,pipe2)
      csp.assemble()(pipe2,lineprinter)
  end)
end

-- 4. Subroutines and Data Representations
--
-- "A coroutine acting as a subroutine is a process operating
-- concurrently with its user process in a parallel command:
-- [subr::SUBROUTINE||X::USER]. [...] The USER will call the subroutine by
-- a pair of commands: subr!(arguments); ...; subr?(results). Any commands
-- between these two will be executed concurrently with the subroutine."

-- 4.1  Function: Division With Remainder
--
-- Problem: 
-- Construct a process to represent a function-type subroutine,
-- which accepts a positive dividend and divisor, and returns 
-- their integer quotient and remainder. Efficiency is of no concern."
--
-- Solution:
-- [DIV :: *[ x,y:integer; X?( x,y) --> 
--      quot,rem:integer; quot = 0; rem = x; 
--      *[rem >= y --> rem = rem - y; quot = quot + 1]; 
--      X!(quot,rem) 
--    ] 
-- || X::USER 
-- ]

csp.div=function()
  return clp.process(function(x, y, res)
      local quot,rem = 0,x
      while rem > y do
        rem = rem - y
        quot = quot+1
      end
      res:push(quot,rem)
  end)
end

-- 4.2 Recursion: Factorial
--
-- Problem:
-- Compute a factorial by the recursive method, to a given limit.
-- 
-- Solution:
-- [fac(i: 1..limit)::
-- *[n:integer;fac(i - 1)?n -->
--    [n = 0 --> fac(i - 1)!1
--    [n > 0 --> fac(i + 1)!n - 1;
--        r:integer;fac(i + 1)?r; fac(i-1)!(n * r)
--    ]]
-- || fac(O)::USER
-- ]
--
-- Note: This unrealistic example introduces the technique 
-- of the "iterative array" which will be used to a better 
-- effect: in later examples. 

csp.fac=function(limit)
  assert(limit>1,"limit must be grater than 1")
  local fac={}
  for i=0,limit+1 do
    fac[i]=clp.channel(0)
  end
  local t=clp.process(function(x, res)
      for i=1,limit+1 do
        clp.process(function(i)
          while true do 
            local n=fac[i-1]:get()
            if n==0 or n==1 then
              fac[i-1]:put(1)
            else
              fac[i]:put(n-1)
              local r=fac[i]:get()
              fac[i-1]:put(n * r)
            end
          end
        end)(i)
      end
  end)()
return fac[0]
end

return csp