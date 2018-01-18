use "buffered"


interface EventHandler
  fun move(x: I32, y: I32) => None
  fun quit() => None
  fun moved(client: U32, x: I32, y: I32) => None
  fun bye(client: U32) => None


primitive Events
  fun read(reader: Reader, handler: EventHandler) =>
    while reader.size() >= 4 do
      let len: U16 = try reader.peek_u16_le()? else 0 end
      if (len == 0) or (reader.size() < len.usize()) then break end
      try _parse(reader, handler)? else reader.clear() end
    end

  fun _parse(reader: Reader, handler: EventHandler) ? =>
    let len = reader.u16_le()?
    let typ = reader.u16_le()?
      match typ
      | Move.id() => Move.parse(reader, len, handler)?
      | Quit.id() => Quit.parse(reader, len, handler)
      | Moved.id() => Moved.parse(reader, len, handler)?
      | Bye.id() => Bye.parse(reader, len, handler)?
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
    writer.>u16_le(12).>u16_le(id()).>i32_le(x).>i32_le(y)

primitive Quit
  fun id(): U16 => 1

  fun parse(reader: Reader, len: U16, handler: EventHandler) =>
    handler.quit()

  fun write(writer: Writer) =>
    writer.>u16_le(4).>u16_le(id())

primitive Moved
  fun id(): U16 => 2

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let client = reader.u32_le()?
    let x = reader.i32_le()?
    let y = reader.i32_le()?
    handler.moved(client, x, y)

  fun write(writer: Writer, client: U32, x: I32, y: I32) =>
    writer.>u16_le(16).>u16_le(id()).>u32_le(client).>i32_le(x).>i32_le(y)

primitive Bye
  fun id(): U16 => 3

  fun parse(reader: Reader, len: U16, handler: EventHandler) ? =>
    let client = reader.u32_le()?
    handler.bye(client)

  fun write(writer: Writer, client: U32) =>
    writer.>u16_le(8).>u16_le(id()).>u32_le(client)
