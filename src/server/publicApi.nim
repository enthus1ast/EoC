## These are the procedures that
## addons or modules can call.
## these procedures should also be called from the script api.

import typesServer
import ../shared/cPlayerTypes
import ../shared/shared
import netlibServer

proc teleport*(gserver: GServer, ent: Entity, x, y: float) =
  ## teleports the given entity to the given position.
  ## if the entity cannot teleport, nothing happens.
  ## Entities that can teleport:
  ## - CompPlayer
  if gserver.reg.hasComponent(ent, CompPlayer):
    var compPlayer = gserver.reg.getComponent(ent, CompPlayer)
    compPlayer.body.position = v(x, y)
  # TODO fanout to all clients on the map? The server must send out the new position in its tick

proc movePlayerToWorldmap*(gserver: GServer, ent: Entity) =
  ## moves the given player directly to the worldmap
  print "movePlayerToWorldmap:", ent
  var compPlayer = gserver.reg.getComponent(ent, CompPlayer)
  if compPlayer.map == WORLDMAP_ENTITY:
    print "Player already on worldmap:", ent
    return

  let res = GResPlayerWorldmap(playerId: compPlayer.id)
  let fres = toFlatty(res)
  let gmsg = GMsg(kind: Kind_PlayerWorldmap, data: fres)
  gserver.sendToAllClientsOnMap(gmsg, compPlayer.map)

  # Remove player from the map he is on
  var compMap = gserver.reg.getComponent(compPlayer.map, CompMap)
  print ent
  echo compMap.players
  compMap.players.excl ent
  echo compMap.players

  # Set the worldmap const to the players maps
  compPlayer.map = WORLDMAP_ENTITY
  print "movePlayerToWorldmap DONE:", ent
  print compMap.players
