import typesAssetLoader
import typesClient

import nimraylib_now
import nim_tiled

proc newAssetLoader*(): AssetLoader =
  result.textures = initTable[string, Texture2D]()
  result.maps = initTable[string, GMap]()

proc loadTexture*(ass: var AssetLoader, relpath: string, key = "") =
  let abspath = getAppDir() / relpath
  if abspath.fileExists:
    ass.textures[if key == "": relpath else: key] = loadTexture(abspath)
    print "Loaded: ", relpath,  abspath
  else:
    print "Does not exist:", abspath

proc loadMap*(ass: var AssetLoader, relpath: string) =
  var map = GMap()
  map.tiled = loadTiledMap(relpath)
  for tileset in map.tiled.tilesets:
    let (dir, name, ext) = tileset.imagePath.splitFile()
    ass.loadTexture("assets/img/tilesets" / name & ext, key = tileset.imagePath) # we overwrite the key to get it easier on tilemap load
  ass.maps[relpath] = map