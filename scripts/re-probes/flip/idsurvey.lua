-- survey: per 68010 object (A2) log every model-id change (PCs 02E22C new slot / 02E360 update), stock speed.
-- env AY (128 normal, 255 Advanced), END, OUT. Output: "frame A2 id" on change.
local m = manager.machine.devices[":mainpcb:maincpu"]; local ms = m.spaces["program"]
local MPC, MA2 = m.state["PC"], m.state["A2"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local sy = F(":mainpcb:8BADC.2","AD Stick Y")
local AY = tonumber(os.getenv("AY") or "128")
local END = tonumber(os.getenv("END") or "9000")
local out = io.open(os.getenv("OUT"), "w")
local frame, last = 0, {}
td = ms:install_write_tap(0x808000, 0x80BFFF, "dat", function(o, d)
  local pc = MPC.value
  if pc == 0x02E22C or pc == 0x02E360 then
    local a2, id = MA2.value, d & 0xffff
    if last[a2] ~= id then last[a2] = id; out:write(string.format("%d %08X %04X\n", frame, a2, id)) end
  end
end)
emu.register_frame_done(function()
  frame = frame + 1; local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720)) and 1 or 0)
  sy:set_value((t >= 730 and t < 990) and AY or 128)
  b1:set_value(t>=920 and ((t//30)%2) or 0)
  if t == END then out:close(); manager.machine:exit() end
end)
