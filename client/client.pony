use "buffered"
use "collections"
use "net"
use "random"
use "time"
use "../sdl"
use "../gamecore"

actor Main
  let env: Env
  let sdl: SDL2
  let timers: Timers = Timers
  let render_loop: Timer tag
  let tick_loop: Timer tag
  let _ponies: Array[Pony] = Array[Pony]
  let _player: PlayerPony
  let _netcontrollers: Map[U32, NetPony] = Map[U32, NetPony]
  let _objects: Array[GameObject] = Array[GameObject]
  var _conn: (TCPConnection | None) = None
  var _writer: Writer

  new create(env': Env) =>
    env = env'
    _writer = Writer
    sdl = SDL2(SDLFlags.init_video(), "tiny horse", WinW(), WinH())
    let server_ip = try env.args(1)? else "::1" end
    let server_port = try env.args(2)? else "6000" end
    sdl.load_texture("data/pony_00.png", 0)
    sdl.load_texture("data/pony_01.png", 1)
    sdl.load_texture("data/pony_02.png", 2)
    sdl.load_texture("data/pony_03.png", 3)
    sdl.load_texture("data/apple.png", 4)
    let mt = MT(Time.millis())
    _player = PlayerPony
    let pos = SpawnPos(mt)
    _ponies.push(Pony(pos._1, pos._2, _player))

    let rtimer = Timer(object iso is TimerNotify
                        let _game: Main = this
                        fun ref apply(timer:Timer, count:U64):Bool =>
                          _game.render()
                          true
                      end, 0, 16_666_667)
    render_loop = rtimer
    timers(consume rtimer)

    let ttimer = Timer(object iso is TimerNotify
                        let _game: Main = this
                        fun ref apply(timer:Timer, count:U64):Bool =>
                          _game.tick()
                          true
                      end, 0, 66_666_667)
    tick_loop = ttimer
    timers(consume ttimer)

    try
      let auth = TCPAuth(env.root as AmbientAuth)
      _conn = TCPConnection(auth, NetNotify(env, this), server_ip, server_port)
    else
      env.exitcode(1)
      return
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
      send_player_move()
      _player.moved = false
    end

  be render() =>
    sdl.>clear().>set_draw_color(92, 111, 57).>fill_rect()
    for obj in _objects.values() do
      obj.draw(sdl)
    end
    for pony in _ponies.values() do
      pony.draw(sdl)
    end
    sdl.present()

  fun ref send(data: Array[ByteSeq] iso) =>
    match _conn
      | let conn: TCPConnection => conn.writev(consume data)
    end

  fun ref send_player_move() =>
    Move.write(_writer, _player.x, _player.y)
    send(_writer.done())

  fun ref send_bye() =>
    Quit.write(_writer)
    send(_writer.done())

  be connected(conn: TCPConnection) =>
    send_player_move()

  fun ref keydown(event: SDLKeyDown) =>
    match event.sym
      | SDLKeyCodes.left() => _player.left = true
      | SDLKeyCodes.right() => _player.right = true
      | SDLKeyCodes.up() => _player.up = true
      | SDLKeyCodes.down() => _player.down = true
    end

  fun ref keyup(event: SDLKeyUp) =>
    match event.sym
      | SDLKeyCodes.escape() => dispose()
      | SDLKeyCodes.left() => _player.left = false
      | SDLKeyCodes.right() => _player.right = false
      | SDLKeyCodes.up() => _player.up = false
      | SDLKeyCodes.down() => _player.down = false
    end

  be dispose() =>
    send_bye()
    timers.cancel(render_loop)
    timers.cancel(tick_loop)
    sdl.dispose()
    match _conn
      | let conn: TCPConnection => conn.dispose()
    end

  be welcome(id: U32) =>
    _player.id = id

  be other_move(id: U32, x: I32, y: I32) =>
    if not _netcontrollers.contains(id) then
      let other = NetPony(id, x, y)
      try
        _netcontrollers.insert(id, other)?
        _ponies.push(Pony(x, y, other))
      end
    else
      try
        _netcontrollers(id)?.move(x, y)
      end
    end

  be other_bye(id: U32) =>
    try
      (_, let other) = _netcontrollers.remove(id)?
      var i: USize = 0
      while i < _ponies.size() do
        if _ponies(i)?.brain() is other then
          _ponies.delete(i)?
        else
          i = i + 1
        end
      end
    end

  be object_add(oid: U16, otype: U16, x: I32, y: I32) =>
    _objects.push(GameObject(oid, otype, x, y))

  be object_del(oid: U16) =>
    try
      ArrayUtils.del_in_place[GameObject](_objects,
        ArrayUtils.find_if[GameObject](_objects, {(item) => item.id == oid})?)?
    end

  be object_count(client: U32, otype: U16, count: U16) =>
    if otype == Apple() then
      if client == _player.id then
        _player.apples = count
      else
        try
          _netcontrollers(client)?.apples = count
        end
      end
    end


class Pony
  var x: I32 = 0
  var y: I32 = 0
  var dir: I32 = 0 // movement dir, 0 = standing still, 1 = right, -1 = left
  var moved: Bool = false
  var apples: U16 = 0
  var _frame: I32 = 0
  var _fcnt: I32 = 0
  var _controller: PonyController

  new create(x': I32, y': I32, controller: PonyController) =>
    x = x'
    y = y'
    _controller = controller

  fun brain(): PonyController tag => _controller

  fun draw(sdl: SDL2) =>
    let img = _controller.framebase() + _frame
    //sdl.set_draw_color(255, 0, 0)
    //sdl.fill_rect(SDLRect(x, y, SpriteW(), SpriteH()))
    if apples > 0 then
      let w = (apples.i32() * 4).min(SpriteW())
      if w == SpriteW() then
        sdl.set_draw_color(0, 0, 255)
      else
        sdl.set_draw_color(52, 152, 219)
      end
      sdl.fill_rect(SDLRect(x, y - 8, w, 4))
    end
    if dir < 0 then
      sdl.draw_texture(img, SDLRect(x, y, SpriteW(), SpriteH()), SDLFlags.flip_horizontal())
    else
      sdl.draw_texture(img, SDLRect(x, y, SpriteW(), SpriteH()))
    end

  fun ref tick() =>
    // only update animation when moving
    if moved then
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
    if x' < 0 then
      dir = -1
    elseif x' > 0 then
      dir = 1
    end
    moved = (x' != 0) or (y' != 0)


class GameObject
  let id: U16
  let typ: U16
  var x: I32
  var y: I32

  new create(id': U16, typ': U16, x': I32, y': I32) =>
    id = id'
    typ = typ'
    x = x'
    y = y'

  fun draw(sdl: SDL2) =>
    // sdl.set_draw_color(0, 0, 255)
    // sdl.fill_rect(SDLRect(x, y, AppleW(), AppleH()))
    sdl.draw_texture(4, SDLRect(x, y, AppleW(), AppleH()))


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
  var id: U32 = 0
  var apples: U16 = 0

  fun ref tick(pony: Pony) =>
    pony.apples = apples
    let dx: I32 = if left and not right then -1 elseif right and not left then 1 else 0 end
    let dy: I32 = if up and not down then -1 elseif down and not up then 1 else 0 end
    pony.walk(dx * 4, dy * 4)
    x = pony.x
    y = pony.y
    if (dx != 0) or (dy != 0) then
      moved = true
    end

  fun framebase(): I32 => 0


class NetPony is PonyController
  let id: U32
  var x: I32
  var y: I32
  var fresh: Bool = true
  var apples: U16 = 0

  new create(id': U32, x': I32, y': I32) =>
    id = id'
    x = x'
    y = y'

  fun ref tick(pony: Pony) =>
    pony.apples = apples
    let dx = x - pony.x
    let dy = y - pony.y
    if fresh then
      pony.walk(dx, dy)
      fresh = false
    else // movement easing
      var mx: I32 = if dx > 0 then ((dx/2) + 1) elseif dx < 0 then ((dx/2) + 1) else 0 end
      var my: I32 = if dy > 0 then ((dy/2) + 1) elseif dy < 0 then ((dy/2) + 1) else 0 end
      pony.walk(mx, my)
    end

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun framebase(): I32 => 2


class NetNotify is (TCPConnectionNotify & EventHandler)
  let _env: Env
  let _game: Main
  var _buf: Reader

  new iso create(env: Env, game: Main) =>
    _env = env
    _game = game
    _buf = Reader

  fun ref connected(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      _env.out.print(Sform("Connected to %:%")(who._1)(who._2).string())
    end
    conn.set_keepalive(30)
    _game.connected(conn)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("Connection failed")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    _buf.append(consume data)
    Events.read(_buf, this)
    true

  fun moved(client: U32, x: I32, y: I32) =>
    _game.other_move(client, x, y)

  fun welcome(client: U32) =>
    _game.welcome(client)

  fun bye(client: U32) =>
    _game.other_bye(client)

  fun object_add(oid: U16, otype: U16, x: I32, y: I32) =>
    _game.object_add(oid, otype, x, y)

  fun object_del(oid: U16) =>
    _game.object_del(oid)

  fun object_count(client: U32, otype: U16, count: U16) =>
    _game.object_count(client, otype, count)
