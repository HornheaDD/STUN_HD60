-- attract mode only (no coin): snapshots at SNAPS="f1 f2 ...", exit at END
local SN = {}
for v in (os.getenv("SNAPS") or ""):gmatch("%d+") do SN[tonumber(v)] = true end
local END = tonumber(os.getenv("END") or "3000")
local frame = 0
emu.register_frame_done(function()
  frame = frame + 1
  if SN[frame] then manager.machine.video:snapshot() end
  if frame == END then manager.machine:exit() end
end)
