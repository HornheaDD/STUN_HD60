-- per drawn list (frames F0..F1): display-list op counts + args of non-polygon ops (op 8 blit: x y flags addr), with the 60 fps script
local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local S = gspd.state
local F0, F1 = tonumber(os.getenv("F0")), tonumber(os.getenv("F1"))
local out = io.open(os.getenv("OUT"), "w")
local frame, ops, oparg = 0, {}, {}
local w = function(a) return gsp:read_u16(a) end
tj = gsp:install_read_tap(0xFFF470E0, 0xFFF472DF, "jt", function(o, d, m)
  if o % 32 ~= 0 or frame < F0 or frame > F1 then return end
  local a4 = S["A4"].value & 0xffff; local op = a4 >> 12
  if (o - 0xFFF470E0) // 32 ~= op then return end
  ops[op] = (ops[op] or 0) + 1
  if op ~= 7 and op ~= 4 then
    local a5 = S["A5"].value; local t = {}
    for i = 0, 4 do t[#t+1] = string.format("%04X", w(a5 + 16*i)) end
    oparg[#oparg+1] = string.format("op%X:%04X[%s]", op, a4, table.concat(t, " "))
  end
end)
tw = gsp:install_write_tap(0xFFF71680, 0xFFF7168F, "dd", function(o, d, m)
  if d == 0 or frame < F0 or frame > F1 then return end
  local t = {}
  for op = 0, 15 do if ops[op] then t[#t+1] = string.format("%X:%d", op, ops[op]) end end
  out:write(string.format("%d ops %s | %s\n", frame, table.concat(t, " "), table.concat(oparg, " ")))
  ops, oparg = {}, {}
end)
emu.register_frame_done(function() frame = frame + 1; if frame == F1 + 2 then out:close() end end)
dofile(os.getenv("HOME") .. "/mame/scripts/re-probes/flip/ab_test.lua")
