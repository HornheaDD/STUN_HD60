local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local n=0
emu.register_frame_done(function() n=n+1
  if n==600 then
    local function words(a, k) local t = {} for i=0,k-1 do t[#t+1] = string.format("%04X", gsp:read_u16(a + i*16)) end return table.concat(t," ") end
    for _,a in ipairs({0xFFE00000, 0xFFE00100, 0xFFDE0000, 0xFFF69580}) do print(string.format("%08X: %s", a, words(a, 16))) end
    local d=manager.machine.debugger
    d:command("dasm "..os.getenv("HOME").."/mame/scripts/re-probes/bg/blit.asm,FFF58950,6000,1,:mainpcb:gsp")
  end
  if n==602 then manager.machine:exit() end end)
