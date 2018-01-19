use "buffered"


interface EventHandler
  fun welcome(client: U32) => None
  fun move(x: I32, y: I32) => None
  fun quit() => None
  fun moved(client: U32, x: I32, y: I32) => None
  fun bye(client: U32) => None
  fun object_add(oid: U16, otype: U16, x: I32, y: I32) => None
  fun object_del(oid: U16) => None
  fun object_count(client: U32, oid: U16, count: U16) => None


primitive Events
  fun read(reader: Reader, handler: EventHandler) =>
    while reader.size() >= 4 do
      let len: U16 = try reader.peek_u16_le()? else 0 end
      if reader.size() < (len.usize() + 4) then break end
      try _parse(reader, handler)? else reader.clear() end
    end

  fun _parse(reader: Reader, handler: EventHandler) ? =>
    let len = reader.u16_le()?
    let typ = reader.u16_le()?
      match typ
      | Welcome.id() => Welcome.parse(reader, len, handler)?
      | Move.id() => Move.parse(reader, len, handler)?
      | Quit.id() => Quit.parse(reader, len, handler)
      | Moved.id() => Moved.parse(reader, len, handler)?
      | Bye.id() => Bye.parse(reader, len, handler)?
      | ObjectAdd.id() => ObjectAdd.parse(reader, len, handler)?
      | ObjectDel.id() => ObjectDel.parse(reader, len, handler)?
      | ObjectCount.id() => ObjectCount.parse(reader, len, handler)?
      else
        error
      end


primitive Move
  fun id(): U16 => 0

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let x = reader.i32_le()?
    let y = reader.i32_le()?
    handler.move(x, y)

  fun write(writer: Writer, x: I32, y: I32) =>
    writer.>u16_le(8).>u16_le(id()).>i32_le(x).>i32_le(y)

primitive Quit
  fun id(): U16 => 1

  fun parse(reader: Reader, len: U16, handler: EventHandler) =>
    handler.quit()

  fun write(writer: Writer) =>
    writer.>u16_le(0).>u16_le(id())

primitive Moved
  fun id(): U16 => 2

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let client = reader.u32_le()?
    let x = reader.i32_le()?
    let y = reader.i32_le()?
    handler.moved(client, x, y)

  fun write(writer: Writer, client: U32, x: I32, y: I32) =>
    writer.>u16_le(12).>u16_le(id()).>u32_le(client).>i32_le(x).>i32_le(y)

primitive Bye
  fun id(): U16 => 3

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let client = reader.u32_le()?
    handler.bye(client)

  fun write(writer: Writer, client: U32) =>
    writer.>u16_le(4).>u16_le(id()).>u32_le(client)


primitive ObjectAdd
  fun id(): U16 => 4

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let oid = reader.u16_le()?
    let otype = reader.u16_le()?
    let x = reader.i32_le()?
    let y = reader.i32_le()?
    handler.object_add(oid, otype, x, y)

  fun write(writer: Writer, oid: U16, otype: U16, x: I32, y: I32) =>
    writer.>u16_le(12).>u16_le(id()).>u16_le(oid).>u16_le(otype).>i32_le(x).>i32_le(y)


primitive ObjectDel
  fun id(): U16 => 5

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let oid = reader.u16_le()?
    handler.object_del(oid)

  fun write(writer: Writer, oid: U16) =>
    writer.>u16_le(2).>u16_le(id()).>u16_le(oid)


primitive ObjectCount
  fun id(): U16 => 6

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let client = reader.u32_le()?
    let oid = reader.u16_le()?
    let count = reader.u16_le()?
    handler.object_count(client, oid, count)

  fun write(writer: Writer, client: U32, oid: U16, count: U16) =>
    writer.>u16_le(8).>u16_le(id()).>u32_le(client).>u16_le(oid).>u16_le(count)


primitive Welcome
  fun id(): U16 => 7

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let client = reader.u32_le()?
    handler.welcome(client)

  fun write(writer: Writer, client: U32) =>
    writer.>u16_le(4).>u16_le(id()).>u32_le(client)
