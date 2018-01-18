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
    let notify = recover iso
      object is TCPListenNotify
        fun ref listening(listen: TCPListener ref) =>
          try
            let me = listen.local_address().name()?
            Sform("Listening on %:%")(me._1)(me._2).print(env.out)
          else
            env.err.print("Couldn't get local address")
            listen.close()
          end

        fun ref not_listening(listen: TCPListener ref) =>
          Sform("Couldn't listen to %:%")(server_ip)(server_port).print(env.err)
          listen.close()

        fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
          GameConnection(env, gameserver)
      end
    end
    try
      TCPListener(env.root as AmbientAuth, consume notify, server_ip, server_port)
    else
      env.err.print("Unable to use the network :(")
      env.exitcode(1)
    end


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
      let name = Sform("%:%")(who._1)(who._2).string()
      _env.out.print("Connection accepted from " + name)
      _client = name.hash().u32()
      _gameserver.connect(_client, conn)
    else
      _env.out.print("Failed to get remote address for accepted connection")
      conn.close()
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if _client == 0 then return true end
    _buf.append(consume data)
    Events.read(_buf, object is EventHandler
      fun move(x: I32, y: I32) => _gameserver.move(_client, x, y)
      fun quit() => _gameserver.bye(_client)
    end)
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_client.string() + " disconnected")
    _gameserver.bye(_client)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")


class Player
  let _conn: TCPConnection tag
  let writer: Writer = Writer
  var x: I32 = 0
  var y: I32 = 0

  new create(conn: TCPConnection tag) =>
    _conn = conn

  fun ref send() =>
    _conn.writev(writer.done())

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun ref bye() =>
    _conn.dispose()


actor GameServer
  let _env: Env
  let _players: Map[U32, Player] = Map[U32, Player]
  let _timers: Timers
  var _loop: (Timer tag | None tag) = None
  var _nplayers: USize = 0

  new create(env: Env) =>
    _env = env
    _timers = Timers
    let game_loop = Timer(object iso is TimerNotify
                            let _server: GameServer = this
                            fun ref apply(timer: Timer, count: U64): Bool =>
                              _server.tick()
                              true
                          end, Nanos.from_millis(50), Nanos.from_millis(50))
    _loop = game_loop
    _timers(consume game_loop)

  be connect(client: U32, conn: TCPConnection tag) =>
    try
      _env.out.print("New player: " + client.string())
      var new_player = Player(conn)
      _players.insert(client, new_player)?

      for (pn, player) in _players.pairs() do
        if client != pn then
          send_move(new_player, pn, player.x, player.y)
          send_move(player, client, new_player.x, new_player.y)
        end
      end
    else
      _env.out.print("Failed to connect new player " + client.string())
    end

  be move(client: U32, x: I32, y: I32) =>
    try
      _players(client)?.move(x, y)
      for (pn, player) in _players.pairs() do
        if client != pn then
          send_move(player, client, x, y)
        end
      end
    end

  be bye(client: U32) =>
    try
      (_, let rmplayer) = _players.remove(client)?
      Sform("% is leaving")(client).print(_env.out)
      rmplayer.bye()
      for (pn, player) in _players.pairs() do
        if client != pn then
          send_bye(player, client)
        end
      end
    end

  be tick() =>
    if _nplayers != _players.size() then
      _env.out.print(_players.size().string() + " players")
      _nplayers = _players.size()
    end

  fun send_move(to: Player, from: U32, x: I32, y: I32) =>
    Moved.write(to.writer, from, x, y)
    to.send()

  fun send_bye(to: Player, from: U32) =>
    Bye.write(to.writer, from)
    to.send()
