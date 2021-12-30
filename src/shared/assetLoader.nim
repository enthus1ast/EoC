import typesAssetLoader
import tables, os, print

import nimraylib_now
import nim_tiled

import freeTexturePacker

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
    print "Loaded texture: ", relpath,  abspath, key
  else:
    print "Does not exist:", abspath

proc loadSpriteSheet*(ass: var AssetLoader, relpath: string, key = "", width = 32, height = 32) =
  ## Loads a spritesheet,
  ## relpath must be pointed to the png file,
  ## The spritesheets expects a json file with the same name:
  ## eg:
  ##  loadSpriteSheet("path/to/img.png")
  ## also loads:
  ##  "path/to/img.json"
  ## the json file must be in asprite or free texture packer format.
  let abspath = getAppDir() / relpath
  if abspath.fileExists:
    ass.textures[if key == "": relpath else: key] = loadTexture(abspath)
  else:
    print "Does not exists:", abspath

  let jsonPath = abspath.changeFileExt("json")
  if jsonPath.fileExists:
    var spriteSheet = SpriteSheet()
    spriteSheet.img = if key == "": relpath else: key
    spriteSheet.texture = freeTexturePacker.loadPackedTexture(jsonPath)
    ass.spriteSheets[if key == "": relpath else: key] = spriteSheet
  else:
    print "Does not exists:", abspath

proc loadMap*(ass: var AssetLoader, relpath: string, key = "", loadTextures = true) =
  var map = loadTiledMap(relpath)
  if loadTextures:
    for tileset in map.tilesets:
      let (dir, name, ext) = tileset.imagePath.splitFile()
      ass.loadTexture("assets/img/tilesets" / name & ext, key = tileset.imagePath) # we overwrite the key to get it easier on tilemap load
  ass.maps[if key == "": relpath else: key] = map