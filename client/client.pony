use "time"
use "random"
use "../sdl"
use "../gamecore"


class Pony
  var _x: I32 = 0
  var _y: I32 = 0
  var _frame: I32 = 0
  var _fcnt: I32 = 0

  new create(x: I32, y: I32) =>
    _x = x
    _y = y

  fun draw(sdl: SDL2) =>
    sdl.draw_texture(_frame, recover val SDLRect(_x, _y, 96, 64) end)

  fun ref tick() =>
    _fcnt = _fcnt + 1
    if _fcnt > 10 then
      _fcnt = 0
      _frame = _frame + 1
    end
    if _frame > 1 then
      _frame = 0
    end
    _x = _x + 1
    if _x < -96 then
      _x = _x + (640 + 96)
    elseif _x > 640 then
      _x = _x - (640 + 96)
    end
    if _y < -64 then
      _y = _y + (480 + 64)
    elseif _y > 480 then
      _y = _y - (480 + 64)
    end


actor Game
  let env: Env
  let sdl: SDL2
  let timers: Timers = Timers
  let render_loop: Timer tag
  let _ponies: Array[Pony] = Array[Pony]

  new create(env': Env) =>
    env = env'
    sdl = SDL2(SDLFlags.init_video(), "tiny horse")

    sdl.load_texture("data/pony.png", 0)
    sdl.load_texture("data/pony2.png", 1)
    let mt = MT(Time.millis())
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32()))
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32()))
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32()))

    let quitter = Timer(object iso
                          let _game:Game = this
                          fun ref apply(timer:Timer, count:U64):Bool =>
                            _game.quit()
                            false
                        fun ref cancel(timer:Timer) => None
                      end, 1_000_000_000 * 5, 0) // 5 Second timeout
    timers(consume quitter)

    let timer = Timer(object iso
                        let _game:Game = this
                        fun ref apply(timer:Timer, count:U64):Bool =>
                          _game.loop()
                          true
                        fun ref cancel(timer:Timer) => None
                      end, 0, 16_666_666) // 60fps
    render_loop = timer
    timers(consume timer)

  be loop() =>
   sdl.clear()
   sdl.set_draw_color(92, 111, 57)
   sdl.fill_rect(None)
   for pony in _ponies.values() do
     pony.tick()
     pony.draw(sdl)
   end
   sdl.present()

  be quit() =>
    dispose()

  be dispose() =>
    timers.cancel(render_loop)
    sdl.dispose()

actor Main
  new create(env:Env) =>
    let game = Game(env)
