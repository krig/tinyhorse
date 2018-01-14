use "time"
use "../sdl"

actor Game
  let sdl: SDL2 tag
  let timers: Timers = Timers
  let render_loop: Timer tag
  var xpos: I32

  new create() =>
    sdl = SDL2(SDLFlags.init_video(), "hello, world!")
    xpos = 100

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
                      end, 0, 33_000_000) // 33ms timeout
    render_loop = timer
    timers(consume timer)

  be loop() =>
   sdl.clear()
   sdl.set_draw_color(0, 0, 255)
   sdl.fill_rect(None)
   sdl.set_draw_color(255, 0, 0)
   let rect: SDLRect trn = recover trn SDLRect(xpos, 100, 200, 200) end
   xpos = xpos + 1
   sdl.fill_rect(consume rect)
   sdl.present()

  be quit() =>
    dispose()

  be dispose() =>
    timers.cancel(render_loop)
    sdl.dispose()

actor Main
  new create(env:Env) =>
    let game = Game
