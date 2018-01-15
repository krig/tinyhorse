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


primitive Bye
  fun id(): U16 => 2

  fun to_server(writer: Writer): Writer =>
    writer.>u16_be(2 + 2).>u16_be(id())

  fun to_client(writer: Writer, client: U32) =>
    writer
      .>u16_be(4 + 4).>u16_be(2)
      .>u32_be(client)
