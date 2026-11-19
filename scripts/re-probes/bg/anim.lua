-- During gameplay: which palette entries (bank 0) change from frame to frame, and which op8 blits happen besides the skyline.
local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local S = gspd.state
local sh = manager.machine.memory.shares
local plo, phi = sh[":mainpcb:gsp_palram_lo"], sh[":mainpcb:gsp_palram_hi"]
local out = io.open(os.getenv("HOME").."/mame/scripts/re-probes/bg/out/anim.txt","w")
local frame, prev, chg, blits = 0, nil, {}, {}
tr = gsp:install_read_tap(0xFFF470E0, 0xFFF472DF, "jt", function(o)
  if o % 32 ~= 0 then return end
  local a4 = S["A4"].value & 0xffff
  if (a4 >> 12) ~= 8 then return end
  local a5 = S["A5"].value
  local k = string.format("x=%04X y=%04X fl=%04X addr=%04X%04X", gsp:read_u16(a5), gsp:read_u16(a5+16), gsp:read_u16(a5+32), gsp:read_u16(a5+48), gsp:read_u16(a5+64))
  blits[k] = (blits[k] or 0) + 1
end)
emu.register_frame_done(function()
  frame = frame + 1
  local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720) or (t>=900 and t<920)) and 1 or 0)
  b1:set_value(t>=1000 and ((t//30)%2) or 0)
  if frame >= 1400 then
    local cur = {}
    for i = 0, 255 do cur[i] = (plo:read_u16(2*i) << 16) | phi:read_u16(2*i) end
    if prev then for i = 0, 255 do if cur[i] ~= prev[i] then chg[i] = (chg[i] or 0) + 1 end end end
    prev = cur
  end
  if frame % 600 == 0 and frame >= 1800 then
    local ks = {} for i, v in pairs(chg) do ks[#ks+1] = string.format("%d:%d", i, v) end
    table.sort(ks)
    out:write(string.format("frames %d-%d pens changed (pen:times): %s\n", frame-599, frame, table.concat(ks, " ")))
    for k, v in pairs(blits) do out:write("   blit ", k, " x", v, "\n") end
    chg, blits = {}, {}
  end
  if frame == 7200 then out:close(); manager.machine:exit() end
end)
