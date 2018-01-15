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
  var _client: U32
  var _buf: Reader

  new iso create(env: Env, gameserver: GameServer tag) =>
    _env = env
    _gameserver = gameserver
    _client = 0
    _buf = Reader

  fun ref accepted(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      _env.out.print("connection accepted from " + who._1 + ":" + who._2)
      _client = (who._1 + ":" + who._2).hash().u32()
      _gameserver.connect(_client, conn)
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
    match typ
    | Move.id() =>
      (let x, let y) = Move.parse(_buf)?
      _gameserver.move(_client, x, y)
    | Bye.id() =>
      _gameserver.bye(_client)
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if _client == 0 then return true end
    _buf.append(consume data)
    _parse_loop()
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_client.string() + " disconnected")
    _gameserver.bye(_client)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")


class Player
  let _conn: TCPConnection tag
  let _writer: Writer
  var x: I32
  var y: I32

  new create(conn: TCPConnection tag) =>
    _conn = conn
    _writer = Writer
    x = 0
    y = 0

  fun ref writer(): Writer => _writer

  fun ref send() =>
    _conn.writev(_writer.done())

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun ref bye() =>
    _conn.dispose()


interface Event
  fun client(): U32

  fun send(player: Player)


class MoveEvent is Event
  let _client: U32
  let _x: I32
  let _y: I32

  new create(client': U32, x': I32, y': I32) =>
    _client = client'
    _x = x'
    _y = y'

  fun client(): U32 => _client

  fun send(player: Player) =>
    Move.to_client(player.writer(), _client, _x, _y)
    player.send()


class ByeEvent is Event
  let _client: U32

  new create(client': U32) =>
    _client = client'

  fun client(): U32 => _client

  fun send(player: Player) =>
    Bye.to_client(player.writer(), _client)
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

  be connect(client: U32, conn: TCPConnection tag) =>
    try
      _env.out.print("New player: " + client.string())
      var new_player = Player(conn)
      _players.insert(client, new_player)?

      for (pn, player) in _players.pairs() do
        if client != pn then
          MoveEvent(pn, player.x, player.y).send(new_player)
          MoveEvent(client, new_player.x, new_player.y).send(player)
        end
      end
    else
      _env.out.print("Failed to connect new player " + client.string())
    end

  be move(client: U32, x: I32, y: I32) =>
    try
      _players(client)?.move(x, y)
      _events.push(MoveEvent(client, x, y))
    end

  be bye(client: U32) =>
    Fmt("% is leaving")(client).print(_env.out)
    try
      (_, let player) = _players.remove(client)?
      _events.push(ByeEvent(client))
      player.bye()
    end

  be tick() =>
    if _nplayers != _players.size() then
      _env.out.print(_players.size().string() + " players")
      _nplayers = _players.size()
    end
    for event in _events.values() do
      for (client, player) in _players.pairs() do
        if event.client() != client then
          event.send(player)
        end
      end
    end
    _events.clear()
