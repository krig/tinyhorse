use "random"

primitive WinW fun apply(): I32 => 768
primitive WinH fun apply(): I32 => 432
primitive SpriteW fun apply(): I32 => 96
primitive SpriteH fun apply(): I32 => 64
primitive AppleW fun apply(): I32 => 32
primitive AppleH fun apply(): I32 => 32
primitive MaxObjs fun apply(): USize => 4

primitive SpawnPos fun apply(mt: MT): (I32, I32) =>
  let rx = (mt.next() % (WinW() - (SpriteW() * 2)).u64()).abs().i32() + SpriteW()
  let ry = (mt.next() % (WinH() - (SpriteH() * 2)).u64()).abs().i32() + SpriteH()
  (rx, ry)
