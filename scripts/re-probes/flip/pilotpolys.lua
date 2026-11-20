-- at each GSP draw-done (FFF71680 != 0): parse the op-7 block of the drawn list, log polys whose first row lies in a box
-- (X0..X1, Y0..Y1 list coords); frames F0..F1. Output: "L frame n" then "flags xl xr y nsegs ..." per poly (offset order)
local gsp = manager.machine.devices[":mainpcb:gsp"].spaces["program"]
local F0, F1 = tonumber(os.getenv("F0")), tonumber(os.getenv("F1"))
local X0, X1, Y0, Y1 = 40, 120, 0x28 + 90, 0x28 + 180
local out = io.open(os.getenv("OUT"), "w")
local frame = 0
local function w(a) return gsp:read_u16(a) end
tg = gsp:install_write_tap(0xfff71680, 0xfff7168f, "dd", function(o, d)
  if d == 0 or frame < F0 or frame > F1 then return end
  local ptr = w(0xfff77f30) | (w(0xfff77f40) << 16)
  for k = 0, 1199 do
    local p = ptr + 16 * k
    if w(p) == 0x7000 then
      local base = p + 16; local cnt = w(base)
      if cnt >= 2 and cnt <= 0x2000 then
        local offs, a3 = {}, base + cnt * 16
        for i = 0, 2047 do local off = w(a3 + 16*i); if off & 0x8000 ~= 0 then break end; if off == 0 or off >= cnt then offs = nil; break end; offs[#offs+1] = off end
        if offs then
          local lines = {}
          for idx, off in ipairs(offs) do
            local a = base + off * 16
            local f, xl, xr, y = w(a), w(a+16), w(a+32), w(a+48)
            if xl >= 0x8000 then xl = xl - 0x10000 end
            if xl >= X0 and xl <= X1 and y >= Y0 and y <= Y1 then
              local segs = {}; local q = a + 64
              for s = 0, 40 do local sr = w(q) | (w(q+16) << 16); if sr == 0xffffffff then break end; segs[#segs+1] = w(q+64); q = q + 80 end
              lines[#lines+1] = string.format("%d %04X %d %d %d [%s]", idx, f, xl, xr, y, table.concat(segs, ","))
            end
          end
          out:write(string.format("L frame %d polys %d inbox %d\n", frame, #offs, #lines))
          out:write(table.concat(lines, "\n"), "\n")
          break
        end
      end
    end
  end
end)
emu.register_frame_done(function() frame = frame + 1; if frame == F1 + 2 then out:close() end end)
dofile(os.getenv("HOME") .. "/mame/scripts/re-probes/flip/ab_test.lua")
