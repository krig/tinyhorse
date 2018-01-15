use "buffered"

primitive Move
  fun id(): U16 => 0
  fun parse(reader: Reader): (I32, I32) ? =>
    let x = reader.i32_be()?
    let y = reader.i32_be()?
    (x, y)
  fun to_server(writer: Writer, x: I32, y: I32): Writer =>
    writer
      .>u16_be(2 + 2 + 4 + 4)
      .>u16_be(id())
      .>i32_be(x)
      .>i32_be(y)
  fun to_client(writer: Writer, client: U32, x: I32, y: I32) =>
    writer
      .>u16_be(2 + 2 + 4 + 4 + 4).>u16_be(id())
      .>u32_be(client).>i32_be(x).>i32_be(y)

primitive Say
  fun id(): U16 => 1
  fun parse(reader: Reader, len: USize): String iso^ ? =>
    String.from_iso_array(reader.block(len)?)
  fun to_server(writer: Writer, msg: String val): Writer =>
    writer
      .>u16_be(2 + 2 + msg.size().u16()).>u16_be(id())
      .>write(msg.array())
  fun to_client(writer: Writer, client: U32, msg: String val) =>
    writer
      .>u16_be(4 + 4 + msg.size().u16()).>u16_be(id())
      .>u32_be(client).>write(msg.array())


primitive Bye
  fun id(): U16 => 2
  fun to_server(writer: Writer): Writer =>
    writer.>u16_be(2 + 2).>u16_be(id())
  fun to_client(writer: Writer, client: U32) =>
    writer
      .>u16_be(4 + 4).>u16_be(2)
      .>u32_be(client)
