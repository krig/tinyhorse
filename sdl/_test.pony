use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestInitVideo)

class iso _TestInitVideo is UnitTest
  fun name(): String => "sdl/init_video"

  fun apply(h: TestHelper) =>
    let sdl = SDL2(SDLFlags.init_video(), "test window")
    sdl.dispose()


