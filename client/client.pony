use "time"
use "random"
use "../sdl"
use "../gamecore"


primitive WinW fun apply(): I32 => 768
primitive WinH fun apply(): I32 => 432
primitive SpriteW fun apply(): I32 => 96
primitive SpriteH fun apply(): I32 => 64

interface PonyController
  fun tick(pony: Pony)

class Pony
  var _x: I32 = 0
  var _y: I32 = 0
  // movement dir, 0 = standing still, 1 = right, -1 = left
  var _dir: I32 = 0
  var _frame: I32 = 0
  var _fcnt: I32 = 0
  var _controller: PonyController

  new create(x: I32, y: I32, controller: PonyController) =>
    _x = x
    _y = y
    _controller = controller

  fun draw(sdl: SDL2) =>
    let img = if _dir == 0 then 1 else _frame end
    sdl.draw_texture(img, recover val SDLRect(_x, _y, SpriteW(), SpriteH()) end)

  fun ref tick() =>
    // only update animation when moving
    if _dir != 0 then
      _fcnt = _fcnt + 1
      if _fcnt > 10 then
        _fcnt = 0
        _frame = _frame + 1
      end
      if _frame > 1 then
        _frame = 0
      end
    end
    _controller.tick(this)
    let fieldw = WinW() + SpriteW()
    let fieldh = WinH() + SpriteH()
    if _x < -SpriteW() then
      _x = _x + fieldw
    elseif _x > WinW() then
      _x = _x - fieldw
    end
    if _y < -SpriteH() then
      _y = _y + fieldh
    elseif _y > WinH() then
      _y = _y - fieldh
    end

  fun ref walk(x': I32, y': I32) =>
    _x = _x + x'
    _y = _y + y'
    _dir = if (x' == 0) and (y' == 0) then 0 elseif x' < 0 then -1 else 1 end


class PlayerPony is PonyController
  var left: Bool = false
  var right: Bool = false
  var up: Bool = false
  var down: Bool = false

  fun tick(pony: Pony) =>
    let dx: I32 = if left and not right then -1 elseif right and not left then 1 else 0 end
    let dy: I32 = if up and not down then -1 elseif down and not up then 1 else 0 end
    pony.walk(dx, dy)

class OtherPony is PonyController
  // otherpony gets movement from network
  fun tick(pony: Pony) =>
    pony.walk(1, 0)

actor Game
  let env: Env
  let sdl: SDL2
  let timers: Timers = Timers
  let render_loop: Timer tag
  let _ponies: Array[Pony] = Array[Pony]
  let _player: PlayerPony

  new create(env': Env) =>
    env = env'
    sdl = SDL2(SDLFlags.init_video(), "tiny horse", WinW(), WinH())

    sdl.load_texture("data/pony.png", 0)
    sdl.load_texture("data/pony2.png", 1)
    let mt = MT(Time.millis())
    _player = PlayerPony
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32(), _player))
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32(), OtherPony))
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32(), OtherPony))

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
    let events: Array[SDLEvent] = sdl.poll_events()
    for event in events.values() do
      match event
        | let _: SDLQuit => dispose()
        | let down: SDLKeyDown => keydown(down)
        | let up: SDLKeyUp => keyup(up)
      end
    end
    sdl.clear()
    sdl.set_draw_color(92, 111, 57)
    sdl.fill_rect(None)
    for pony in _ponies.values() do
      pony.tick()
      pony.draw(sdl)
    end
    sdl.present()

  fun ref keydown(event: SDLKeyDown) =>
    if event.sym == SDLKeyCodes.left() then _player.left = true end
    if event.sym == SDLKeyCodes.right() then _player.right = true end
    if event.sym == SDLKeyCodes.up() then _player.up = true end
    if event.sym == SDLKeyCodes.down() then _player.down = true end

  fun ref keyup(event: SDLKeyUp) =>
    if event.sym == SDLKeyCodes.escape() then dispose() end
    if event.sym == SDLKeyCodes.left() then _player.left = false end
    if event.sym == SDLKeyCodes.right() then _player.right = false end
    if event.sym == SDLKeyCodes.up() then _player.up = false end
    if event.sym == SDLKeyCodes.down() then _player.down = false end

  be dispose() =>
    timers.cancel(render_loop)
    sdl.dispose()

actor Main
  new create(env:Env) =>
    let game = Game(env)
