-- disassemble the GSP display-list walker and the non-3D opcode handlers (output stays local: ROM-derived)
local n=0
local D=os.getenv("HOME").."/mame/scripts/re-probes/bg/"
local H={ {"walker","FFF46E30",0x2B0}, {"op2","FFF47E20",0x800}, {"op3","FFF47900",0x200}, {"op4","FFF48650",0x390},
  {"op5","FFF47AF0",0x330}, {"op6","FFF477C0",0x140}, {"op8","FFF489E0",0x240}, {"op9","FFF48C20",0x3A0},
  {"opA","FFF49AF0",0x550}, {"opB","FFF4A040",0x3E0}, {"opC","FFF4A420",0x1A0}, {"opD","FFF4A5C0",0x600}, {"opE","FFF472E0",0x4F0} }
emu.register_frame_done(function() n=n+1
  if n==600 then local d=manager.machine.debugger
    for _,h in ipairs(H) do d:command(string.format("dasm %s%s.asm,%s,%X,1,:mainpcb:gsp", D, h[1], h[2], h[3]*16)) end end
  if n==610 then manager.machine:exit() end end)
