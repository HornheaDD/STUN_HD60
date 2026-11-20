-- per-frame host time (ms) from frame F0 to F1 into WLOG, then runs ab_test.lua (inputs + the 60 fps script)
local tps = emu.osd_ticks_per_second(); local prev; local n = 0
local F0, F1 = tonumber(os.getenv("F0") or "600"), tonumber(os.getenv("F1") or "2400")
local f = io.open(os.getenv("WLOG"), "w")
emu.register_frame_done(function() n = n + 1; local w = emu.osd_ticks()
  if prev and n > F0 and n <= F1 then f:write(string.format("%d %.2f\n", n, (w - prev) / tps * 1000)) end
  if n == F1 then f:close() end
  prev = w end)
dofile(os.getenv("HOME") .. "/mame/scripts/re-probes/flip/ab_test.lua")
