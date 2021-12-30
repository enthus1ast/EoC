import tables
import nimraylib_now
import nim_tiled
import freeTexturePacker
type
  Key* = string
  # GMap* = object
  #   tiled*: TiledMap
  SpriteSheet* = object
    img*: Key
    texture*: freeTexturePacker.Texture


  AssetLoader* = object
    textures*: Table[Key, Texture2D]
    # maps*: Table[Key, GMap]
    maps*: Table[Key, TiledMap]
    spriteSheets*: Table[Key, SpriteSheet]



