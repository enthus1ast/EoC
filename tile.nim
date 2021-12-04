import nim_tiled
import print
let map = loadTiledMap("assets/maps/demoTown.tmx")
var tileset = map.tilesets[0]
# print map
# print tileset.regions
# print map.objectGroups

# print TiledPolygon(map.objectGroups[0].objects[0]).points
# print tileset

# for layer in map.layers:
  # echo layer.name
#   for y in 0..<layer.height:
#     for x in 0..<layer.width:
#       let index = x + y * layer.width
#       let gid = layer.tiles[index]
#       print gid