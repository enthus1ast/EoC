import typesServer
import ../shared/shared

proc sendToAllClients*(gserver: GServer, gmsg: GMsg) =
  ## Sends a `GMsg` to all clients connected to the server
  let msg = toFlatty(gmsg)
  for id, entPlayer in gserver.players:
    var compPlayerServer = gserver.reg.getComponent(entPlayer, CompPlayerServer)
    gserver.server.send(compPlayerServer.connection, msg)

proc sendToAllClientsOnMap*(gserver: GServer, gmsg: GMsg, map: Entity) =
  ## Sends a `GMsg` to all clients on the given map
  if map == WORLDMAP_ENTITY:
    gprint "i will not send to worlmap entity in sendToAllClientsOnMap"
    return
  let compMap = gserver.reg.getComponent(map, CompMap)
  let msg = toFlatty(gmsg)
  for entPlayer in compMap.players:
    var compPlayerServer = gserver.reg.getComponent(entPlayer.Entity, CompPlayerServer)
    gserver.server.send(compPlayerServer.connection, msg)
