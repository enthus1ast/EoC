import typesAssetLoader
import typesClient

proc newAssetLoader*(): AssetLoader =
  result.textures = initTable[string, Texture2D]()

proc loadTexture*(ass: var AssetLoader, relpath: string) =
  let abspath = getAppDir() / relpath
  ass.textures[relpath] = loadTexture(abspath)
  print "Loaded: ", abspath