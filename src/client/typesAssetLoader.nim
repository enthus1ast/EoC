import tables
import nimraylib_now
type
  AssetLoader* = object
    textures*: Table[string, Texture2D]