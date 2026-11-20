-- disassemble the GSP's alternate (bit 12) polygon handler = scaled sprite blit; output ../sprite/out/gsp_alt_full.asm
local n=0
emu.register_frame_done(function() n=n+1
  if n==1500 then
    local d=manager.machine.debugger
    d:command("dasm " .. os.getenv("HOME") .. "/mame/scripts/re-probes/sprite/out/gsp_alt_full.asm,FFF48FC0,6000,1,:mainpcb:gsp")
  end
  if n==1510 then manager.machine:exit() end end)
