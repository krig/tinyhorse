use "collections"
use "net"
use "time"

actor Main
  new create(env: Env) =>
    let gameserver = GameServer(env)
    try
      TCPListener(env.root as AmbientAuth, Listener(env, gameserver), "", "8102")
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
  var _id: String

  new iso create(env: Env, gameserver: GameServer tag) =>
    _env = env
    _gameserver = gameserver
    _id = ""

  fun ref accepted(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      _env.out.print("connection accepted from " + who._1 + ":" + who._2)
      _id = who._1 + ":" + who._2
    else
      _env.out.print("Failed to get remote address for accepted connection")
      conn.close()
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if _id == "" then return true end
    // split input into lines
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print("server closed")

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")

class Ticker is TimerNotify
  let _server: GameServer tag

  new iso create(server: GameServer tag) =>
    _server = server

  fun apply(timer: Timer, count: U64): Bool =>
    _server.tick()
    true

actor Player
  let _name: String val
  var _x: I32
  var _y: I32
  var _msg: String
  var _msgtimeout: I32

  new create(name': String val) =>
    _name = name'
    _x = 0
    _y = 0
    _msg = ""
    _msgtimeout = 0

  fun name(): String val => _name

  fun ref update() =>
    None


actor GameServer is TimerNotify
  let _env: Env
  let _players: Map[String val, Player] = Map[String val, Player]
  let _timers: Timers
  var _loop: (Timer tag | None tag) = None

  new create(env: Env) =>
    _env = env
    _timers = Timers
    let game_loop = Timer(Ticker(this), Nanos.from_millis(100), Nanos.from_millis(100))
    _loop = game_loop
    _timers(consume game_loop)

  be new_player(name: String val, player: Player tag) =>
    try
      _players.insert(name, player)?
      _env.out.print("Added player: " + name)
    end

  be move(id: String val, x: I32, y: I32) =>
    None

  be say(id: String val, msg: String val) =>
    None

  be bye(id: String val) =>
    None

  be tick() =>
    _env.out.print("TICK (" + _players.size().string() + " players)")
    // send out all movements

  fun ref quit() =>
    match _loop
      | let l: Timer tag => _timers.cancel(l)
    end
