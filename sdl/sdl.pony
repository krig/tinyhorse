use "lib:SDL2"
use "lib:SDL2_image"
use "collections"

use @SDL_Init[I32](flags: U32)
use @SDL_CreateWindow[Pointer[_SDLWindow]](title: Pointer[U8] tag, x: I32, y: I32, w: I32, h: I32, flags: U32)
use @SDL_CreateRenderer[Pointer[_SDLRenderer]](window: Pointer[_SDLWindow], index: I32, flags: U32)
use @SDL_DestroyRenderer[None](renderer: Pointer[_SDLRenderer])
use @SDL_DestroyWindow[None](window: Pointer[_SDLWindow])
use @SDL_RenderClear[I32](renderer: Pointer[_SDLRenderer])
use @SDL_RenderPresent[None](renderer: Pointer[_SDLRenderer])
use @SDL_SetRenderDrawColor[I32](renderer: Pointer[_SDLRenderer], r: U8, g: U8, b: U8, a: U8)
use @SDL_RenderFillRect[I32](renderer: Pointer[_SDLRenderer], rect: MaybePointer[_SDLRect val])
use @IMG_LoadTexture[Pointer[_SDLTexture]](renderer: Pointer[_SDLRenderer], file: Pointer[U8] tag)
use @SDL_QueryTexture[I32](texture: Pointer[_SDLTexture], format: Pointer[U32], access: Pointer[I32], w: Pointer[I32], h: Pointer[I32])

use @SDL_RenderCopy[I32](renderer: Pointer[_SDLRenderer],
  texture: Pointer[_SDLTexture],
  srcrect: MaybePointer[_SDLRect val],
  dstrect: MaybePointer[_SDLRect val])
use @SDL_RenderCopyEx[I32](renderer: Pointer[_SDLRenderer],
  texture: Pointer[_SDLTexture],
  srcrect: MaybePointer[_SDLRect val],
  dstrect: MaybePointer[_SDLRect val],
  angle: F64,
  center: MaybePointer[_SDLPoint val],
  flip: U32)

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

struct _SDLPoint
  var x: I32 = 0
  var y: I32 = 0

  new create(x1: I32, y1: I32) =>
    x = x1
    y = y1

primitive _SDLWindow
primitive _SDLRenderer
primitive _SDLTexture


class SDLRect
  let rect: _SDLRect
  new create(x1: I32, y1: I32, w1: I32, h1: I32) =>
    rect = _SDLRect.create(x1, y1, w1, h1)

class SDLTexture
  let texture: Pointer[_SDLTexture]
  new create(texture': Pointer[_SDLTexture]) =>
    texture = texture'

primitive SDLFlags
  fun init_video(): U32 => 0x00000020
  fun window_shown(): U32 => 0x00000004
  fun renderer_accelerated(): U32 => 0x00000002
  fun renderer_presentvsync(): U32 => 0x00000004

  fun flip_none(): U32 => 0x0
  fun flip_horizontal(): U32 => 0x1
  fun flip_vertical(): U32 => 0x2

class SDL2
  var window: SDLWindow
  var renderer: SDLRenderer
  var textures: Map[I32, SDLTexture] = Map[I32, SDLTexture]

  new create(flags: U32, title: String val) =>
    @SDL_Init(flags)
    window = SDLWindow(title)
    renderer = SDLRenderer(window)

  fun ref clear() =>
    renderer.clear()

  fun ref set_draw_color(r: U8, g: U8, b: U8, a: U8 = 255) =>
    renderer.set_draw_color(r, g, b, a)

  fun ref fill_rect(rect: (SDLRect val | None)) =>
    renderer.fill_rect(rect)

  fun ref draw_texture(id: I32, rect: SDLRect val) =>
    try
      let tex = textures(id)?
      renderer.draw_texture(tex, rect)
    end

  fun ref present() =>
    renderer.present()

  fun ref dispose() =>
    renderer.destroy()
    window.destroy()

  fun ref load_texture(file: String val, id: I32) =>
    try
      textures.insert(id, renderer.load_texture(file)?)?
    end


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

  fun ref load_texture(file: String box): SDLTexture ? =>
    let texture: Pointer[_SDLTexture] = @IMG_LoadTexture(renderer, file.cstring())
    if texture.is_null() then
      error
    end
    SDLTexture(texture)

  fun ref draw_texture(texture: SDLTexture, rect: SDLRect val) =>
    let srcrect: _SDLRect trn = recover trn _SDLRect(0, 0, 0, 0) end
    var format: U32 = 0
    var access: I32 = 0
    @SDL_QueryTexture(texture.texture, addressof format, addressof access, addressof srcrect.w, addressof srcrect.h)
    @SDL_RenderCopy(renderer, texture.texture,
    MaybePointer[_SDLRect val](consume srcrect),
    MaybePointer[_SDLRect val](rect.rect))

