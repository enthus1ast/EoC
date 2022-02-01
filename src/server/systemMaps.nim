# The system that is is manageging all the maps.
import typesServer
import ../shared/shared
import ../shared/assetLoader
import ../shared/cMap

import typesSystemMaps
export typesSystemMaps

proc loadMaps(gserver: Gserver) =
  ## Load the maps from the filesystem.
  echo "Load maps:"
  gserver.assets.loadMap("../client/assets/maps/demoTown.tmx", loadTextures = false)
  gserver.assets.loadMap("../client/assets/maps/demoTown2.tmx", loadTextures = false)

proc spawnMaps(gserver: Gserver, pgserver: pointer) =
  ## Generate maps entities
  var compMap = CompMap()
  compMap.space = newSpace()
  compMap.space.userdata = pgserver #unsafeAddr gserver
  compMap.space.gravity = v(0, 0)
  let entMap = gserver.newMap("../client/assets/maps/demoTown.tmx", compMap.space)
  gserver.maps[DEMO_MAP_POS] = entMap # Demo map is at 0,0
  gserver.reg.addComponent(entMap, compMap)

  # TODO dummy map loading in the server
  # echo entMap
  var compMap2 = CompMap()
  compMap2.space = newSpace()
  compMap2.space.userdata = pgserver #unsafeAddr gserver
  compMap2.space.gravity = v(0, 0)
  let entMap2 = gserver.newMap("../client/assets/maps/demoTown2.tmx", compMap.space)
  gserver.maps[DEMO_MAP_POS + Vector2(x: -1, y: 0 )] = entMap2 # Demo map is at 0,0
  gserver.reg.addComponent(entMap2, compMap2)


proc removePlayerFromALlMaps(gserver: GServer, entPlayer: Entity) =
  for entMap in gserver.maps.values:
    var compMap = gserver.reg.getComponent(entMap, CompMap)
    compMap.players.excl(entPlayer)

proc connectEvents(gserver: Gserver, pgserver: pointer) =
  ## Connect the events that are relevant for the maps
  # When a player disconnects, remove all traces of him from the maps
  gserver.reg.connect(EvPlayerDisconnected,
    proc (ev: EvPlayerDisconnected) {.closure.} =
      gprint "[systemMaps] removePlayerFromALlMaps", ev
      var gserver2 = cast[ptr Gserver](ev.pgserver)[]
      gserver2.removePlayerFromALlMaps(ev.entPlayer)
  )

proc newSystemMaps*(gserver: Gserver, pgserver: pointer): SystemMaps =
  gserver.loadMaps()
  gserver.spawnMaps(pgserver)
  gserver.connectEvents(pgserver)
