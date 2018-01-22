use "ponytest"
use "random"
use "collections"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestSpawnPos)
    test(_TestArrayUtils)

class iso _TestSpawnPos is UnitTest
  fun name(): String => "gamecore/spawnpos"

  fun apply(h: TestHelper) =>
    let mt = MT(100)
    let lst: Array[(I32, I32)] = []
    for n in Range[I32](0, 20000) do
      lst.push(SpawnPos(mt))
    end
    for (x, y) in lst.values() do
      h.assert_true(x >= SpriteW())
      h.assert_true(y >= SpriteH())
      h.assert_true(x <= (WinW() - SpriteW()))
      h.assert_true(y <= (WinH() - SpriteH()))
    end


class iso _TestArrayUtils is UnitTest
  fun name(): String => "gamecore/arrayutils"

  fun apply(h: TestHelper) =>
    let a: Array[I32] = [1; 4; 2; 9; 100; -10; 0; -2]
    let idx = try ArrayUtils.find_if[I32](a, {(e) => e < 0})? else 0 end
    h.assert_eq[USize](idx, 5)
    try ArrayUtils.del_in_place[I32](a, 3)? end
    h.assert_array_eq[I32]([1; 4; 2; -2; 100; -10; 0], a)
