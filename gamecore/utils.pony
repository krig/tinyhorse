// various utility things

class ArrayUtils
  fun del_in_place[A](array: Array[A], i: USize) ? =>
    try
      if i >= array.size() then error end
      let last = array.size() - 1
      if i != last then
        array.swap_elements(i, last)?
      end
      array.pop()?
    else
      error
    end
