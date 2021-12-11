import typesAssetLoader
import tables, os, print

import nimraylib_now
import nim_tiled

proc newAssetLoader*(): AssetLoader =
  result.textures = initTable[string, Texture2D]()
  result.maps = initTable[string, TiledMap]()

proc loadTexture*(ass: var AssetLoader, relpath: string, key = "") =
  ## Loads a texture from `relpath`, with the given `key`.
  ## The `relpath` is expanded to an absolute path, root is the appDir.
  ## If `key` is empty the `relpath` is used as a key.
  let abspath = getAppDir() / relpath
  if abspath.fileExists:
    ass.textures[if key == "": relpath else: key] = loadTexture(abspath)
    print "Loaded: ", relpath,  abspath
  else:
    print "Does not exist:", abspath

proc loadMap*(ass: var AssetLoader, relpath: string, key = "") =
  var map = loadTiledMap(relpath)
  for tileset in map.tilesets:
    let (dir, name, ext) = tileset.imagePath.splitFile()
    ass.loadTexture("assets/img/tilesets" / name & ext, key = tileset.imagePath) # we overwrite the key to get it easier on tilemap load
  ass.maps[if key == "": relpath else: key] = map