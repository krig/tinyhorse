use "buffered"
use "collections"
use "net"
use "time"
use "../gamecore"


actor Main
  new create(env: Env) =>
    let server_ip = try env.args(1)? else "::1" end
    let server_port = try env.args(2)? else "6000" end
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
          ClientConnection(env, gameserver)
      end
    end
    try
      TCPListener(env.root as AmbientAuth, consume notify, server_ip, server_port)
    else
      env.err.print("Unable to use the network :(")
      env.exitcode(1)
    end


class ClientConnection is (TCPConnectionNotify & EventHandler)
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
    Events.read(_buf, this)
    true

  fun move(x: I32, y: I32) =>
    _gameserver.move(_client, x, y)

  fun quit() =>
    _gameserver.bye(_client)

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_client.string() + " disconnected")
    _gameserver.bye(_client)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")


class Player
  let _conn: TCPConnection tag
  let _writer: Writer = Writer
  var x: I32 = 0
  var y: I32 = 0

  new create(conn: TCPConnection tag) =>
    _conn = conn

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun ref bye() =>
    _conn.dispose()

  fun ref send_move(from: U32, x': I32, y': I32) =>
    Moved.write(_writer, from, x', y')
    _conn.writev(_writer.done())

  fun ref send_bye(from: U32) =>
    Bye.write(_writer, from)
    _conn.writev(_writer.done())



actor GameServer
  let _env: Env
  let _players: Map[U32, Player] = Map[U32, Player]

  new create(env: Env) =>
    _env = env

  be connect(client: U32, conn: TCPConnection tag) =>
    try
      _env.out.print("New player: " + client.string())
      var new_player = Player(conn)
      _players.insert(client, new_player)?

      for (pn, player) in _players.pairs() do
        if client != pn then
          new_player.send_move(pn, player.x, player.y)
          player.send_move(client, new_player.x, new_player.y)
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
          player.send_move(client, x, y)
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
          player.send_bye(client)
        end
      end
    end
