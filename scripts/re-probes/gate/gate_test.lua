-- headless: coin, start, Advanced course (stick Y held up until the trigger), fire, then the 60 fps script.
-- SNAPS="f1 f2 ..." or SNAPR="from to" (every frame) take snapshots; END ends the run.
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local sy = F(":mainpcb:8BADC.2","AD Stick Y")
local AY = tonumber(os.getenv("AY") or "255")
local END = tonumber(os.getenv("END") or "6000")
local SN = {}
for v in (os.getenv("SNAPS") or ""):gmatch("%d+") do SN[tonumber(v)] = true end
local r0, r1 = (os.getenv("SNAPR") or ""):match("(%d+)%s+(%d+)")
r0, r1 = tonumber(r0), tonumber(r1)
local frame = 0
emu.register_frame_done(function()
  frame = frame + 1; local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720)) and 1 or 0)
  sy:set_value((t >= 730 and t < 990) and AY or 128)
  b1:set_value(t>=920 and ((t//30)%2) or 0)
  if SN[frame] or (r0 and frame >= r0 and frame <= r1) then manager.machine.video:snapshot() end
  if frame == END then manager.machine:exit() end
end)
dofile(os.getenv("HOME") .. "/mame/scripts/stunrun-interp60.lua")
