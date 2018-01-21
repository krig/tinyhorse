use "itertools"

class Sform is Stringable
  let _fmt: String box
  var _args: Array[String box] = []

  new create(fmt: String box) =>
    _fmt = fmt

  fun ref apply(arg: Stringable box): Sform =>
    _args.push(arg.string())
    this

  fun ref a[A: Stringable #read](arg: A): Sform =>
    _args.push(arg.string())
    this

  fun string(): String iso^ =>
    let buflen = _fmt.size() + Iter[String box](_args.values())
      .fold[USize](USize(0), {(sum, s) => sum + s.size()})
    let buf = recover iso String(buflen) end
    buf.append(_fmt)
    var offset = ISize(0)
    for arg in _args.values() do
      while true do
        try
          offset = try buf.find("%", offset)? else -1 end
          if (offset < 0) or (buf(offset.usize() + 1)? != '%') then
            break
          end
          buf.delete(offset, 1)
          offset = offset + 1
        else
          break
        end
      end
      if offset < 0 then break end
      buf.cut_in_place(offset, offset + 1)
      buf.insert_in_place(offset, arg)
      offset = offset + arg.size().isize()
    end
    consume buf
