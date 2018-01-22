// various utility things
use "random"

// Generate a random position on the screen
primitive SpawnPos fun apply(mt: MT): (I32, I32) =>
  let rx = (mt.next() % (WinW() - (SpriteW() * 2)).u64()).abs().i32() + SpriteW()
  let ry = (mt.next() % (WinH() - (SpriteH() * 2)).u64()).abs().i32() + SpriteH()
  (rx, ry)


class ArrayUtils
  // del_in_place: Delete an element, compacting
  // the array with as little work as possible by
  // moving the element to be deleted into the
  // last position, and then popping that off the
  // array.
  fun del_in_place[A](array: Array[A], i: USize) ? =>
    if i >= array.size() then error end
    try
      let last = array.size() - 1
      if i != last then array.swap_elements(i, last)? end
      array.pop()?
    else
      error
    end

  // find_if: Return the index of the first element
  // in the array which satisfies the predicate.
  fun find_if[A](array: Array[A] box, predicate: {(box->A!): Bool} val): USize ? =>
    for (i, elem) in array.pairs() do
      if predicate(elem) then
        return i
      end
    end
    error

