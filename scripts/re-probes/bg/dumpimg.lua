local gsp = manager.machine.devices[":mainpcb:gsp"].spaces["program"]
local n=0
emu.register_frame_done(function() n=n+1
  if n==3000 then
    local f=io.open(os.getenv("HOME").."/mame/scripts/re-probes/bg/out/ffe0.bin","wb"); local t={}
    for a=0xFFE00000, 0xFFE00000+0x20000*8-16, 16 do local w=gsp:read_u16(a); t[#t+1]=string.char(w&0xff, w>>8) end
    f:write(table.concat(t)); f:close(); manager.machine:exit() end end)
