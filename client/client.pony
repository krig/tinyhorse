use "time"
use "random"
use "net"
use "collections"
use "../sdl"
use "../gamecore"


primitive WinW fun apply(): I32 => 768
primitive WinH fun apply(): I32 => 432
primitive SpriteW fun apply(): I32 => 96
primitive SpriteH fun apply(): I32 => 64


class Pony
  var x: I32 = 0
  var y: I32 = 0
  // movement dir, 0 = standing still, 1 = right, -1 = left
  var dir: I32 = 0
  var _frame: I32 = 0
  var _fcnt: I32 = 0
  var _controller: PonyController

  new create(x': I32, y': I32, controller: PonyController) =>
    x = x'
    y = y'
    _controller = controller

  fun draw(sdl: SDL2) =>
    let img = _controller.framebase() + _frame
    sdl.draw_texture(img, recover val SDLRect(x, y, SpriteW(), SpriteH()) end)

  fun ref tick() =>
    // only update animation when moving
    if dir != 0 then
      _fcnt = _fcnt + 1
      if _fcnt > 1 then
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
    if x < -SpriteW() then
      x = x + fieldw
    elseif x > WinW() then
      x = x - fieldw
    end
    if y < -SpriteH() then
      y = y + fieldh
    elseif y > WinH() then
      y = y - fieldh
    end

  fun ref walk(x': I32, y': I32) =>
    x = x + x'
    y = y + y'
    dir = if (x' == 0) and (y' == 0) then 0 elseif x' < 0 then -1 else 1 end


interface PonyController
  fun ref tick(pony: Pony)
  fun framebase(): I32


class PlayerPony is PonyController
  var left: Bool = false
  var right: Bool = false
  var up: Bool = false
  var down: Bool = false
  var x: I32 = 0
  var y: I32 = 0
  var moved: Bool = false

  fun ref tick(pony: Pony) =>
    let dx: I32 = if left and not right then -1 elseif right and not left then 1 else 0 end
    let dy: I32 = if up and not down then -1 elseif down and not up then 1 else 0 end
    pony.walk(dx * 2, dy * 2)
    x = pony.x
    y = pony.y
    if (dx != 0) or (dy != 0) then
      moved = true
    end

  fun framebase(): I32 => 0

class OtherPony is PonyController
  let id: String val
  var x: I32
  var y: I32

  new create(id': String val, x': I32, y': I32) =>
    id = id'
    x = x'
    y = y'

  // otherpony gets movement from network
  fun ref tick(pony: Pony) =>
    let dx = x - pony.x
    let dy = y - pony.y
    var mx: I32 = if dx > 0 then 1 elseif dx < 0 then -1 else 0 end
    var my: I32 = if dy > 0 then 1 elseif dy < 0 then -1 else 0 end
    if dx.abs() > 16 then mx = dx end
    if dy.abs() > 16 then my = dy end
    pony.walk(mx, my)

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun framebase(): I32 => 2

actor Game
  let env: Env
  let sdl: SDL2
  let timers: Timers = Timers
  let render_loop: Timer tag
  let tick_loop: Timer tag
  let _ponies: Array[Pony] = Array[Pony]
  let _player: PlayerPony
  let _otherponies: Map[String val, OtherPony] = Map[String val, OtherPony]
  var _outconn: (TCPConnection | None) = None
  var _sendconn: (TCPConnection | None) = None

  new create(env': Env, server_ip: String val, server_port: String val) =>
    env = env'
    sdl = SDL2(SDLFlags.init_video(), "tiny horse", WinW(), WinH())

    sdl.load_texture("data/pony_00.png", 0)
    sdl.load_texture("data/pony_01.png", 1)
    sdl.load_texture("data/pony_02.png", 2)
    sdl.load_texture("data/pony_03.png", 3)
    let mt = MT(Time.millis())
    _player = PlayerPony
    _ponies.push(Pony((mt.next() % 640).abs().i32(), (mt.next() % 480).abs().i32(), _player))

    let rtimer = Timer(object iso
                        let _game:Game = this
                        fun ref apply(timer:Timer, count:U64):Bool =>
                          _game.render()
                          true
                        fun ref cancel(timer:Timer) => None
                      end, 0, 16_666_667) // 30fps
    render_loop = rtimer
    timers(consume rtimer)

    let ttimer = Timer(object iso
                        let _game:Game = this
                        fun ref apply(timer:Timer, count:U64):Bool =>
                          _game.tick()
                          true
                        fun ref cancel(timer:Timer) => None
                      end, 0, 66_666_667) // 15fps
    tick_loop = ttimer
    timers(consume ttimer)

    // setup network
    try
      _outconn = TCPConnection(env.root as AmbientAuth, NetNotify(env, this), server_ip, server_port)
    end


  be tick() =>
    let events: Array[SDLEvent] = sdl.poll_events()
    for event in events.values() do
      match event
        | let _: SDLQuit => dispose()
        | let down: SDLKeyDown => keydown(down)
        | let up: SDLKeyUp => keyup(up)
      end
    end
    for pony in _ponies.values() do
      pony.tick()
    end
    if _player.moved then
      send_text(Fmt("move % %\n")(_player.x)(_player.y).string())
      _player.moved = false
    end

  be render() =>
    sdl.clear()
    sdl.set_draw_color(92, 111, 57)
    sdl.fill_rect(None)
    for pony in _ponies.values() do
      pony.draw(sdl)
    end
    sdl.present()

  fun ref send_text(text: String box) =>
    match _sendconn
      | let conn: TCPConnection => conn.write(text.clone().array())
    end

  be connected(conn: TCPConnection) =>
    _sendconn = conn
    send_text(Fmt("move % %\n")(_player.x)(_player.y).string())

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
    send_text("bye\n")
    timers.cancel(render_loop)
    timers.cancel(tick_loop)
    sdl.dispose()
    match _outconn
      | let conn: TCPConnection => conn.dispose()
    end

  be other_move(id: String val, x: I32, y: I32) =>
    if not _otherponies.contains(id) then
      let other = OtherPony(id, x, y)
      try
        _otherponies.insert(id, other)?
        _ponies.push(Pony(x, y, other))
        env.out.print("Creating avatar for " + id)
      end
    else
      try
        _otherponies(id)?.move(x, y)
      end
    end

  be other_say(id: String val, msg: String val) =>
    None

  be other_bye(id: String val) =>
    None


class NetNotify is TCPConnectionNotify
  let _env: Env
  let _game: Game
  var _buf: String ref = String(128)

  new iso create(env: Env, game: Game) =>
    _env = env
    _game = game

  fun ref connected(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      _env.out.print("Connected to " + who._1 + ":" + who._2)
    end
    conn.set_keepalive(30)
    _game.connected(conn)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("Connection failed")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    _buf.append(consume data)
    _parse_loop()
    true

  fun ref _parse_loop() =>
    while true do
      let cmdend = try _buf.find("\n")? else break end
      let cmd = _buf.substring(0, cmdend)
      _buf.cut_in_place(0, cmdend + 1)
      _parse(consume cmd)
    end

  fun ref _parse(cmd: String) =>
    let input: Array[String val] = cmd.split(" ")
    try
      let command = input.shift()?
      let id = input.shift()?
      match command
      | "move" =>
        let x = input.shift()?.i32()?
        let y = input.shift()?.i32()?
        _game.other_move(id, x, y)
      | "say" =>
        _game.other_say(id, " ".join(input.values()))
      | "bye" =>
        _game.other_bye(id)
      end
    else
      _env.out.print("parse error from server: " + cmd)
    end


actor Main
  new create(env:Env) =>
    var server_ip: String val = ""
    var server_port: String val = ""
    try
      if env.args.size() != 3 then error end
      server_ip = env.args(1)?
      server_port = env.args(2)?
    else
      env.err.print("Usage: " + try env.args(0)? else "" end + " <server-ip> <server-port>")
      env.exitcode(1)
      return
    end

    let game = Game(env, server_ip, server_port)
