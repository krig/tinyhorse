use "lib:SDL2"

use @SDL_Init[I32](flags: U32)
use @SDL_CreateWindow[Pointer[_SDLWindow]](title: Pointer[U8] tag, x: I32, y: I32, w: I32, h: I32, flags: U32)
use @SDL_CreateRenderer[Pointer[_SDLRenderer]](window: Pointer[_SDLWindow], index: I32, flags: U32)
use @SDL_DestroyRenderer[None](renderer: Pointer[_SDLRenderer])
use @SDL_DestroyWindow[None](window: Pointer[_SDLWindow])
use @SDL_RenderClear[I32](renderer: Pointer[_SDLRenderer])
use @SDL_RenderPresent[None](renderer: Pointer[_SDLRenderer])
use @SDL_SetRenderDrawColor[I32](renderer: Pointer[_SDLRenderer], r: U8, g: U8, b: U8, a: U8)
use @SDL_RenderFillRect[I32](renderer: Pointer[_SDLRenderer], rect: MaybePointer[_SDLRect val])

struct _SDLRect
  var x: I32 = 0
  var y: I32 = 0
  var w: I32 = 0
  var h: I32 = 0

  new create(x1: I32, y1: I32, w1: I32, h1: I32) =>
    x = x1
    y = y1
    w = w1
    h = h1

primitive _SDLWindow
primitive _SDLRenderer


class SDLRect
  let rect: _SDLRect
  new create(x1: I32, y1: I32, w1: I32, h1: I32) =>
    rect = _SDLRect.create(x1, y1, w1, h1)

primitive SDLFlags
  fun init_video(): U32 => 0x00000020
  fun window_shown(): U32 => 0x00000004
  fun renderer_accelerated(): U32 => 0x00000002
  fun renderer_presentvsync(): U32 => 0x00000004


actor SDL2
  var window: SDLWindow
  var renderer: SDLRenderer

  new create(flags: U32, title: String val) =>
    @SDL_Init(flags)
    window = SDLWindow(title)
    renderer = SDLRenderer(window)

  be clear() =>
    renderer.clear()

  be set_draw_color(r: U8, g: U8, b: U8, a: U8 = 255) =>
    renderer.set_draw_color(r, g, b, a)

  be fill_rect(rect: (SDLRect val | None)) =>
    renderer.fill_rect(rect)

  be present() =>
    renderer.present()

  be dispose() =>
    renderer.destroy()
    window.destroy()


class SDLWindow
  var window: Pointer[_SDLWindow]

  new create(title: String box, x: I32 = 100, y: I32 = 100, w: I32 = 640, h: I32 = 480, flags: U32 = SDLFlags.window_shown()) =>
    window = @SDL_CreateWindow(title.cstring(), x, y, w, h, flags)

  fun ref destroy() =>
    @SDL_DestroyWindow(window)

class SDLRenderer
  var renderer: Pointer[_SDLRenderer]

  new create(window: SDLWindow) =>
    renderer = @SDL_CreateRenderer(window.window, -1, SDLFlags.renderer_accelerated() or SDLFlags.renderer_presentvsync())

  fun ref destroy() =>
    @SDL_DestroyRenderer(renderer)

  fun ref clear() =>
    @SDL_RenderClear(renderer)

  fun ref set_draw_color(r: U8, g: U8, b: U8, a: U8 = 255) =>
    @SDL_SetRenderDrawColor(renderer, r, g, b, a)

  fun ref fill_rect(rect: (SDLRect val | None)) =>
    match rect
      | None => @SDL_RenderFillRect(renderer, MaybePointer[_SDLRect val].none())
      | let r: SDLRect val => @SDL_RenderFillRect(renderer, MaybePointer[_SDLRect val](r.rect))
    end

   fun ref present() =>
     @SDL_RenderPresent(renderer)
