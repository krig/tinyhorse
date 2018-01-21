use "buffered"
use "collections"
use "net"
use "random"
use "time"
use "../gamecore"


actor Main
  let _env: Env
  let _mt: MT = MT(Time.millis())
  let _timers: Timers = Timers
  let _players: Map[U32, Player] = Map[U32, Player]
  let _objects: Map[U16, GameObject] = Map[U16, GameObject]
  var _next_goid: U16 = 0

  new create(env: Env) =>
    _env = env
    _timers(Timer(object iso is TimerNotify
      let _server: Main = this
      fun ref apply(timer:Timer, count:U64):Bool =>
        _server.spawn()
        false
      end, next_spawn()))

    let server_ip = try env.args(1)? else "::1" end
    let server_port = try env.args(2)? else "6000" end

    let notify = recover iso
      object is TCPListenNotify
        let _server: Main = this
        fun ref listening(listen: TCPListener ref) =>
          try
            let me = listen.local_address().name()?
            env.out.print(Sform("Listening on %:%")(me._1)(me._2).string())
          else
            env.err.print("Couldn't get local address")
            listen.close()
          end

        fun ref not_listening(listen: TCPListener ref) =>
          env.err.print(Sform("Couldn't listen to %:%")(server_ip)(server_port).string())
          listen.close()

        fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
          ClientConnection(env, _server)
      end
    end
    try
      TCPListener(env.root as AmbientAuth, consume notify, server_ip, server_port)
    else
      env.err.print("Unable to use the network :(")
      env.exitcode(1)
    end

  fun ref next_spawn(): U64 => Nanos.from_seconds(3) + (_mt.next() % Nanos.from_seconds(8))

  be spawn() =>
    if _objects.size() < MaxObjs() then
      let pos = SpawnPos(_mt)
      let typ = Apple()
      let gobj = GameObject(typ, pos._1, pos._2)
      _objects(_next_goid) = gobj
      _env.out.print(Sform("Spawning at %, %!")(pos._1)(pos._2).string())
      for (pn, player) in _players.pairs() do
        player.send_object_add(_next_goid, typ, pos._1, pos._2)
      end
      _next_goid = _next_goid + 1
    end
    _timers(Timer(object iso is TimerNotify
      let _server: Main = this
      fun ref apply(timer:Timer, count:U64):Bool =>
        _server.spawn()
        false
      end, next_spawn()))

  be connect(client: U32, conn: TCPConnection tag) =>
    try
      _env.out.print("New player: " + client.string())
      var new_player = Player(conn)

      new_player.send_welcome(client)
      for (oid, obj) in _objects.pairs() do
        new_player.send_object_add(oid, obj.typ, obj.x, obj.y)
      end

      for (pn, player) in _players.pairs() do
        new_player.send_move(pn, player.x, player.y)
        for (otype, ocount) in player.objects.pairs() do
          new_player.send_object_count(pn, otype, ocount)
        end
        player.send_move(client, new_player.x, new_player.y)
      end

      _players.insert(client, new_player)?
    else
      _env.out.print("Failed to connect new player " + client.string())
    end

  be move(client: U32, x: I32, y: I32) =>
    try
      let player = _players(client)?
      player.move(x, y)
      for (pn, other) in _players.pairs() do
        if client != pn then
          other.send_move(client, x, y)
        end
      end
      player_take_on_move(client, player)?
    end

  fun ref player_take_on_move(id: U32, player: Player) ? =>
    let eaten: Array[U16] = []
    for (oid, obj) in _objects.pairs() do
      if player.collides(obj) then
        eaten.push(oid)
      end
    end
    for eid in eaten.values() do
      (_, let eobj) = _objects.remove(eid)?
      let count = player.take(eobj)
      _env.out.print(Sform("% eats % type % at %, %, has now eaten %")(id)(eid)(eobj.typ)(eobj.x)(eobj.y)(count).string())
      for (pn, other) in _players.pairs() do
        other.send_object_del(eid)
        other.send_object_count(id, eobj.typ, count)
      end
    end

  be bye(client: U32) =>
    try
      (_, let rmplayer) = _players.remove(client)?
      _env.out.print(Sform("% is leaving")(client).string())
      rmplayer.bye()
      for (pn, player) in _players.pairs() do
        if client != pn then
          player.send_bye(client)
        end
      end
    end


class ClientConnection is (TCPConnectionNotify & EventHandler)
  let _env: Env
  let _main: Main tag
  var _client: U32
  var _buf: Reader

  new iso create(env: Env, main: Main tag) =>
    _env = env
    _main = main
    _client = 0
    _buf = Reader

  fun ref accepted(conn: TCPConnection ref) =>
    try
      let who = conn.remote_address().name()?
      let name: String val = Sform("%:%")(who._1)(who._2).string()
      _env.out.print("Connection accepted from " + name)
      _client = name.hash().u32()
      _main.connect(_client, conn)
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
    _main.move(_client, x, y)

  fun quit() =>
    _main.bye(_client)

  fun ref closed(conn: TCPConnection ref) =>
    _env.out.print(_client.string() + " disconnected")
    _main.bye(_client)

  fun ref connect_failed(conn: TCPConnection ref) =>
    _env.out.print("connect failed")


class Player
  let _conn: TCPConnection tag
  let _writer: Writer = Writer
  var x: I32 = 0
  var y: I32 = 0
  var objects: Map[U16, U16] = Map[U16, U16]

  new create(conn: TCPConnection tag) =>
    _conn = conn

  fun ref move(x': I32, y': I32) =>
    x = x'
    y = y'

  fun ref bye() =>
    _conn.dispose()

  fun ref take(obj: GameObject): U16 =>
    let count = U16(1) + try objects(obj.typ)? else 0 end
    objects(obj.typ) = count
    count

  fun collides(obj: GameObject): Bool =>
    let phalf = (SpriteW() / 2, SpriteH() / 2)
    let ohalf = (AppleW() / 2, AppleH() / 2)
    let ppos = (x + phalf._1, y + phalf._2)
    let opos = (obj.x + ohalf._1, obj.y + ohalf._2)

    let dx = opos._1 - ppos._1
    let px = (ohalf._1 + phalf._1) - dx.abs().i32()
    if px <= 0 then return false end

    let dy = opos._2 - ppos._2
    let py = (ohalf._2 + phalf._2) - dy.abs().i32()
    if py <= 0 then return false end

    true

  fun ref send_welcome(to: U32) =>
    Welcome.write(_writer, to)
    _conn.writev(_writer.done())

  fun ref send_move(from: U32, x': I32, y': I32) =>
    Moved.write(_writer, from, x', y')
    _conn.writev(_writer.done())

  fun ref send_bye(from: U32) =>
    Bye.write(_writer, from)
    _conn.writev(_writer.done())

  fun ref send_object_add(oid: U16, otype: U16, x': I32, y': I32) =>
    ObjectAdd.write(_writer, oid, otype, x', y')
    _conn.writev(_writer.done())

  fun ref send_object_del(oid: U16) =>
    ObjectDel.write(_writer, oid)
    _conn.writev(_writer.done())

  fun ref send_object_count(of: U32, otype: U16, count: U16) =>
    ObjectCount.write(_writer, of, otype, count)
    _conn.writev(_writer.done())


class GameObject
  let typ: U16
  var x: I32
  var y: I32

  new create(typ': U16, x': I32, y': I32) =>
    typ = typ'
    x = x'
    y = y'
