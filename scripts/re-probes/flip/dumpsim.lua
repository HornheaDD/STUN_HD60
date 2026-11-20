local R = manager.machine.memory.regions[":mainpcb:user1"]
local t = {}
for i = 0, R.size // 2 - 1 do local v = R:read_u16(i * 2); t[#t+1] = string.char(v & 0xff, v >> 8) end
local f = io.open(os.getenv("OUT"), "wb"); f:write(table.concat(t)); f:close(); manager.machine:exit()
