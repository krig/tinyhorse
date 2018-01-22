// various utility things

class ArrayUtils
  // Delete in place: Will swap the element to be
  // deleted into the last position, and then pop
  // that off the array in order to minimize
  // allocations.
  fun del_in_place[A](array: Array[A], i: USize) ? =>
    if i >= array.size() then error end
    try
      let last = array.size() - 1
      if i != last then array.swap_elements(i, last)? end
      array.pop()?
    else
      error
    end

  fun find_if[A](array: Array[A] box, predicate: {(box->A!): Bool} val): USize ? =>
    for (i, elem) in array.pairs() do
      if predicate(elem) then
        return i
      end
    end
    error

