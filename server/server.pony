use "buffered"
use "collections"
use "net"
use "time"
use "../gamecore"


actor Main
  new create(env: Env) =>
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

    let gameserver = GameServer(env)
    try
      TCPListener(env.root as AmbientAuth, Listener(env, gameserver), server_ip, server_port)
    else
      env.out.print("Unable to use the network :(")
    end


class Listener is TCPListenNotify
  let _env: Env
  let _gameserver: GameServer tag

  new iso create(env: Env, gameserver: GameServer tag) =>
    _env = env
    _gameserver = gameserver

  fun ref listening(listen: TCPListener ref) =>
    try
      let me = listen.local_address().name()?
      _env.out.print("Listening on " + me._1 + ":" + me._2)
    else
      _env.err.print("Couldn't get local address")
      listen.close()
    end

  fun ref not_listening(listen: TCPListener ref) =>
    _env.err.print("Couldn't listen")
    listen.close()

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    GameConnection(_env, _gameserver)


class GameConnection is TCPConnectionNotify
  let _env: Env
  let _gameserver: GameServer tag
  var _id: U32
  var _buf: Reader

  new iso create(env: Env, gameserver: GameServer tag) =>
    _env = env
    _gameserver = gameserver
    _id = 0
    _buf = Reader

  fun ref accepted(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      _env.out.print("connection accepted from " + who._1 + ":" + who._2)
      _id = (who._1 + ":" + who._2).hash().u32()
      _gameserver.connect(_id, conn)
    else
      _env.out.print("Failed to get remote address for accepted connection")
      conn.close()
    end

  fun ref _parse_loop() =>
    while _buf.size() >= 4 do
      let len: U16 = try _buf.peek_u16_be()? else 0 end
      if (len == 0) or (_buf.size() < len.usize()) then break end
      try
        _parse()?
      else
        _buf.clear()
        break
      end
    end

  fun ref _parse() ? =>
    let len = _buf.u16_be()?
    let typ = _buf.u16_be()?
    if typ == 0 then // move
      let x = _buf.i32_be()?
      let y = _buf.i32_be()?
      _gameserver.move(_id, x, y)
    elseif typ == 1 then // say
      let msg = _buf.block((len - 4).usize())?
      _gameserver.say(_id, String.from_iso_array(consume msg))
    elseif typ == 2 then // bye
      _gameserver.bye(_id)
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if _id == 0 then return true end
    _buf.append(consume data)
    _parse_loop()
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_id.string() + " disconnected")
    _gameserver.bye(_id)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")


class Player
  let _conn: TCPConnection tag
  let _writer: Writer
  var x: I32
  var y: I32
  var msg: String ref
  var msgtimeout: I32

  new create(conn: TCPConnection tag) =>
    _conn = conn
    _writer = Writer
    x = 0
    y = 0
    msg = "".clone()
    msgtimeout = 0

  fun ref update() =>
    if msgtimeout > 0 then
      msgtimeout = msgtimeout - 1
      if msgtimeout == 0 then
        msg.clear()
      end
    end

  fun ref writer(): Writer => _writer

  fun ref send() =>
    _conn.writev(_writer.done())

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun ref say(msg': String box) =>
    msg.clear()
    msg.insert_in_place(0, msg')
    msgtimeout = 100

  fun ref bye() =>
    _conn.dispose()

interface Event
  fun id(): U32
  fun send(player: Player)

class Move is Event
  let _id: U32
  let _x: I32
  let _y: I32
  new create(id': U32, x': I32, y': I32) =>
    _id = id'
    _x = x'
    _y = y'

  fun id(): U32 => _id

  fun send(player: Player) =>
    player.writer()
      .>u16_be(4 + 4 + 4 + 4)
      .>u16_be(0)
      .>u32_be(_id)
      .>i32_be(_x)
      .>i32_be(_y)
    player.send()

class Say is Event
  let _id: U32
  let _msg: String val
  new create(id': U32, msg': String val) =>
    _id = id'
    _msg = msg'

  fun id(): U32 => _id

  fun send(player: Player) =>
    player.writer()
      .>u16_be(4 + 4 + _msg.size().u16())
      .>u16_be(1)
      .>u32_be(_id)
      .>write(_msg)
    player.send()

class Bye is Event
  let _id: U32
  new create(id': U32) =>
    _id = id'

  fun id(): U32 => _id

  fun send(player: Player) =>
    player.writer()
      .>u16_be(4 + 4)
      .>u16_be(2)
      .>u32_be(_id)
    player.send()


class Ticker is TimerNotify
  let _server: GameServer tag

  new iso create(server: GameServer tag) =>
    _server = server

  fun apply(timer: Timer, count: U64): Bool =>
    _server.tick()
    true


actor GameServer is TimerNotify
  let _env: Env
  let _players: Map[U32, Player] = Map[U32, Player]
  let _events: Array[Event] = []
  let _timers: Timers
  var _loop: (Timer tag | None tag) = None
  var _nplayers: USize = 0

  new create(env: Env) =>
    _env = env
    _timers = Timers
    let game_loop = Timer(Ticker(this), Nanos.from_millis(16), Nanos.from_millis(16))
    _loop = game_loop
    _timers(consume game_loop)

  be connect(id: U32, conn: TCPConnection tag) =>
    try
      _env.out.print("New player: " + id.string())
      var new_player = Player(conn)
      _players.insert(id, new_player)?

      for (pn, player) in _players.pairs() do
        if id != pn then
          Move(pn, player.x, player.y).send(new_player)
          if player.msgtimeout > 0 then
            Say(pn, player.msg.clone()).send(new_player)
          end
          Move(id, new_player.x, new_player.y).send(player)
        end
      end
    else
      _env.out.print("Failed to connect new player " + id.string())
    end

  be move(id: U32, x: I32, y: I32) =>
    try
      _players(id)?.move(x, y)
      _events.push(Move(id, x, y))
    end

  be say(id: U32, msg: String val) =>
    try
      _players(id)?.say(msg)
      _events.push(Say(id, msg))
    end

  be bye(id: U32) =>
    Fmt("% is leaving")(id).print(_env.out)
    try
      (_, let player) = _players.remove(id)?
      _events.push(Bye(id))
      player.bye()
    end

  be tick() =>
    if _nplayers != _players.size() then
      _env.out.print(_players.size().string() + " players")
      _nplayers = _players.size()
    end
    for player in _players.values() do
      player.update()
    end
    for event in _events.values() do
      for (id, player) in _players.pairs() do
        if event.id() != id then
          event.send(player)
        end
      end
    end
    _events.clear()
