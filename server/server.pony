use "collections"
use "net"
use "time"
use "../gamecore"


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
  var _buf: String ref = String(128)

  new iso create(env: Env, gameserver: GameServer tag) =>
    _env = env
    _gameserver = gameserver
    _id = ""

  fun ref accepted(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      _env.out.print("connection accepted from " + who._1 + ":" + who._2)
      _id = who._1 + ":" + who._2
      _gameserver.connect(_id, conn)
    else
      _env.out.print("Failed to get remote address for accepted connection")
      conn.close()
    end

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
      match command
      | "move" =>
        let x = input.shift()?.i32()?
        let y = input.shift()?.i32()?
        _gameserver.move(_id, x, y)
      | "say" =>
        _gameserver.say(_id, " ".join(input.values()))
      | "bye" =>
        _gameserver.bye(_id)
      end
    else
      _env.out.print("parse error from " + _id + ": " + cmd)
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if _id == "" then return true end
    _buf.append(consume data)
    _parse_loop()
    true

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_id + " disconnected")
    _gameserver.bye(_id)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")


class Player
  let _conn: TCPConnection tag
  var x: I32
  var y: I32
  var msg: String ref
  var msgtimeout: I32

  new create(conn: TCPConnection tag) =>
    _conn = conn
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

  fun send(cmd: String val) =>
    _conn.write(cmd.array())

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
  fun name(): String val
  fun send(player: Player)

class Move is Event
  let _name: String val
  let _x: I32
  let _y: I32
  new create(name': String val, x': I32, y': I32) =>
    _name = name'
    _x = x'
    _y = y'

  fun name(): String val => _name

  fun send(player: Player) =>
    player.send(Fmt("move % % %\n")(_name)(_x)(_y).string())

class Say is Event
  let _name: String val
  let _msg: String val
  new create(name': String val, msg': String val) =>
    _name = name'
    _msg = msg'

  fun name(): String val => _name

  fun send(player: Player) =>
    player.send(Fmt("say % %\n")(_name)(_msg).string())

class Bye is Event
  let _name: String val
  new create(name': String val) =>
    _name = name'

  fun name(): String val => _name

  fun send(player: Player) =>
    player.send(Fmt("bye %\n")(_name).string())


class Ticker is TimerNotify
  let _server: GameServer tag

  new iso create(server: GameServer tag) =>
    _server = server

  fun apply(timer: Timer, count: U64): Bool =>
    _server.tick()
    true


actor GameServer is TimerNotify
  let _env: Env
  let _players: Map[String val, Player] = Map[String val, Player]
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

  be connect(name: String val, conn: TCPConnection tag) =>
    try
      _env.out.print("New player: " + name)
      var new_player = Player(conn)
      _players.insert(name, new_player)?

      for (pn, player) in _players.pairs() do
        if name != pn then
          Move(pn, player.x, player.y).send(new_player)
          if player.msgtimeout > 0 then
            Say(pn, player.msg.clone()).send(new_player)
          end
          Move(name, new_player.x, new_player.y).send(player)
        end
      end
    else
      _env.out.print("Failed to connect new player " + name)
    end

  be move(name: String val, x: I32, y: I32) =>
    try
      _players(name)?.move(x, y)
      _events.push(Move(name, x, y))
    end

  be say(name: String val, msg: String val) =>
    try
      _players(name)?.say(msg)
      _events.push(Say(name, msg))
    end

  be bye(name: String val) =>
    Fmt("% is leaving")(name).print(_env.out)
    try
      (_, let player) = _players.remove(name)?
      _events.push(Bye(name))
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
      for (name, player) in _players.pairs() do
        if event.name() != name then
          event.send(player)
        end
      end
    end
    _events.clear()
