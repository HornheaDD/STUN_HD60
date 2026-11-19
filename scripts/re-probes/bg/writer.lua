-- who writes the skyline buffer (GSP RAM FFE00000..)? log 68010 PC + GSP PC histogram per frame window
local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local m68 = manager.machine.devices[":mainpcb:maincpu"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local frame, hist = 0, {}
local out = io.open(os.getenv("HOME").."/mame/scripts/re-probes/bg/out/writer.txt","w")
tw = gsp:install_write_tap(0xFFE00000, 0xFFE3FFFF, "w", function(o, d, m)
  if frame < 1100 or frame > 4750 then return end
  local k = string.format("68k %06X gsp %08X", m68.state["PC"].value, gspd.state["PC"].value)
  hist[k] = (hist[k] or 0) + 1
end)
emu.register_frame_done(function()
  frame = frame + 1
  local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720) or (t>=900 and t<920)) and 1 or 0)
  b1:set_value(t>=1000 and ((t//30)%2) or 0)
  if frame == 4760 then
    local ks = {} for k, v in pairs(hist) do ks[#ks+1] = {k, v} end
    table.sort(ks, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(30, #ks) do out:write(ks[i][2], " ", ks[i][1], "\n") end
    out:close(); manager.machine:exit() end
end)
