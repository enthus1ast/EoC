import tables
import nimraylib_now
import nim_tiled
type
  GMap* = object
    tiled*: TiledMap

  AssetLoader* = object
    textures*: Table[string, Texture2D]
    maps*: Table[string, GMap]