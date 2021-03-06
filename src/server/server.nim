import print, os, flatty, tables, intsets, asyncdispatch
import nimraylib_now/mangled/raymath # Vector2
import nimraylib_now/mangled/raylib  # Vector2
import std/[monotimes, times, strutils, random, locks]

import typesServer

# Components
import ../shared/shared
import ../shared/deltaCalculator
import ../shared/cMap
import ../shared/cPlayer
import ../shared/cTriggers

#Systems
import systemPhysic
import systemMaps

# Aux
import netlibServer
import clisystem
import publicApi
import ../shared/assetLoader

const SERVER_VERSION = 3

func configure(gserver: GServer) =
  gserver.targetServerFps = gserver.config.getSectionValue("net", "targetServerFps").parseInt().uint8
  gserver.targetServerPhysicFps = gserver.config.getSectionValue("net", "targetServerPhysicFps").parseInt().uint8

proc dumpConnectedPlayers(gserver: GServer) =
  echo "Connected players: ", gserver.players.len
  for id, entPlayer in gserver.players:
    let compPlayer = gserver.reg.getComponent(entPlayer, CompPlayer)
    let compPlayerServer = gserver.reg.getComponent(entPlayer, CompPlayerServer)
    # print id, entPlayer, compPlayer, compPlayerServer # FIXME (crash illegal storage)

proc genServerInfo(gserver: GServer): GResServerInfo =
  GResServerInfo(
    targetServerFps: gserver.targetServerFps,
    serverVersion: SERVER_VERSION
  )

proc newPlayer(gserver: GServer, entMap: Entity,
    pos: Vector2, name: string, connection: netty.Connection): Entity {.gcsafe.} =
  discard
  # TODO this is mostly duplicated code from typesClient newPlayer
  # find a way to deduplicate
  result = gserver.reg.newEntity()
  var compPlayer: CompPlayer # = new(CompPlayer)
  compPlayer = CompPlayer()
  compPlayer.id = connection.id.Id # the network id from netty
  compPlayer.pos = pos
  compPlayer.oldpos = pos # on create set both equal
  compPlayer.lastmove = getMonoTime()
  let radius = 5.0 # TODO these must be configured globally
  let mass = 1.0 # TODO these must be configured globally


  var compMap = gserver.reg.getComponent(entMap, CompMap)
  compMap.players.incl result # add entPlayer to the given map
  compPlayer.map = entMap
  compPlayer.body = addBody(compMap.space, newBody(mass, float.high))
  compPlayer.body.userdata = cast[pointer](result)
  compPlayer.body.position = v(pos.x, pos.y)
  compPlayer.shape = addShape(compMap.space, newCircleShape(compPlayer.body, radius, vzero))
  compPlayer.shape.friction = 0.1 # TODO these must be configured globally

  ## We create a "control" body, this body we move around
  ## on keypresses
  compPlayer.controlBody = newKinematicBody()
  compPlayer.controlBody.position = v(pos.x, pos.y)
  compPlayer.desiredPosition = v(pos.x, pos.y)

  ## Linear joint
  compPlayer.controlJoint = addConstraint(compMap.space,
    newPivotJoint(compPlayer.controlBody, compPlayer.body, vzero, vzero)
  )
  compPlayer.controlJoint.maxBias = 0 # disable joint correction
  compPlayer.controlJoint.errorBias = 0 # attempt to fully correct the joint each step
  compPlayer.controlJoint.maxForce = 1000.0 # emulate linear friction

  # compPlayer.angularJoint = addConstraint(compMap.space,
  #   newGearJoint(compPlayer.controlBody, compPlayer.body, 0.0, 1.0)
  # )
  # compPlayer.angularJoint.maxBias = 2147483647 # TODO is this correct?
  # compPlayer.angularJoint.errorBias = 0
  # compPlayer.angularJoint.maxForce = 2147483647 # TODO is this correct?

  gserver.reg.addComponent(result, compPlayer)

  var compPlayerServer = CompPlayerServer()
  compPlayerServer.id = connection.id.Id
  compPlayerServer.connection = connection
  compPlayerServer.pos = v(pos.x, pos.y) #Vector2(x: (rand(50) + 20).float, y: (rand(50) + 20).float) # TODO
  gserver.reg.addComponent(result, compPlayerServer)

  gserver.players[connection.id.Id] = result
  # gserver.reg.addComponent(result, CompName(name: name)) # TODO add player name

  # TODO add CompHealth


  ## Register player collision callback
  proc playerCallback(a: Arbiter; space: Space; data: pointer): bool {.cdecl.} =
    ## Collision callback definition
    print "COLLISION" #, pgclient
    if space.userdata.isNil:
      print  space.userdata.isNil
    else:
      print space.userdata.isNil
      print space.userdata
      var gserver = cast[ref GServer](space.userdata)[] # TODO why? Gserver is already a ref # TODO this must be either gserver or GServer!
      var bodyA: chipmunk7.Body
      var bodyB: chipmunk7.Body
      a.bodies(addr bodyA, addr bodyB)
      print bodyA.userdata, bodyB.userdata

      var entA =
        if not bodyA.userdata.isNil:
          cast[Entity](bodyA.userdata)
        else:
          0.Entity

      var entB =
        if not bodyB.userdata.isNil:
          cast[Entity](bodyB.userdata)
        else:
          0.Entity
      return

      if gserver.reg.hasComponent(entB, CompTrigger[GServer]):
        var compTrigger = gserver.reg.getComponent(entB, CompTrigger[GServer])
        echo "TRIGGER" # TODO this should call the associated trigger script/building function?
        if not compTrigger.onEnter.isNil:
          compTrigger.onEnter(gserver, entA, entB)
        return false # trigger has no collision

    result = true
  var handler = compMap.space.addCollisionHandler(cast[CollisionType](0), cast[CollisionType](0))
  handler.beginFunc = cast[CollisionBeginFunc](playerCallback)


  ## Register destructor
  proc compPlayerDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    gprint "in implicit internal destructor: " #, CompPlayer(comp)
    # TODO should the destructor tell other network players?
    var compPlayer = CompPlayer(comp) #gclient.reg.getComponent(entity, CompPlayer)
    compMap.space.removeShape(compPlayer.shape)
    compMap.space.removeBody(compPlayer.body)
    compMap.space.removeConstraint(compPlayer.controlJoint)
    gserver.players.del(compPlayer.id) # TODO remove PROPERLY from server reg
  gserver.reg.addComponentDestructor(CompPlayer, compPlayerDestructor)


proc mainNetworkTick(ptrgserver: ptr GServer, delta: float) {.gcsafe.} =
  var gserver = ptrgserver[]
  gserver.server.tick()
  for connection in gserver.server.newConnections:
    echo "[new] ", connection.address

    let entPlayer = gserver.newPlayer(
      entMap = gserver.maps[DEMO_MAP_POS], # TODO get real map from datastore
      connection = connection,
      pos = Vector2(x: (rand(50) + 20).float, y: (rand(50) + 20).float), # TODO get real pos from datastore
      name = "TODO NAME"
    )

    gserver.dumpConnectedPlayers()

    # send the new connecting player the server info
    let fGResServerInfo = toFlatty(gserver.genServerInfo())
    gserver.server.send(connection, toFlatty(GMsg(kind: Kind_ServerInfo, data: fGResServerInfo)))

    # send the new connecting player his id
    let fgResYourIdIs = toFlatty(GResYourIdIs(playerId: connection.id.Id))
    gserver.server.send(connection, toFlatty(GMsg(kind: Kind_YourIdIs, data: fgResYourIdIs)))

    # update the new connected player at all the other players
    # let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    # server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))
    for id, entPlayer in gserver.players:
      if id != connection.id.Id:
        let compPlayer = gserver.reg.getComponent(entPlayer, CompPlayer)
        let res = GResPlayerConnected(playerId: id, pos: compPlayer.body.position)
        let fres = toFlatty(res)
        gserver.server.send(connection, toFlatty(GMsg(kind: Kind_PlayerConnected, data: fres)))

    # tell every other player about the new connected player
    let compPlayer = gserver.reg.getComponent(entPlayer, CompPlayer)
    let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id.Id, pos: compPlayer.body.position))
    gserver.sendToAllClients(GMsg(kind: Kind_PlayerConnected, data: fgResPlayerConnected))

  for connection in gserver.server.deadConnections:
    gprint "[dead] ", connection.address, connection.id
    let entPlayer = gserver.players[connection.id.Id]
    gserver.lock.acquire()
    gserver.reg.trigger(EvPlayerDisconnected(entPlayer: entPlayer, id: connection.id.Id, reason: "Lost connection.", pgserver: unsafeAddr gserver))
    gserver.lock.release()
    gserver.reg.destroyEntity(entPlayer)
    gserver.dumpConnectedPlayers()
    let fgResPlayerDisconnects = toFlatty(GResPlayerDisconnects(playerId: connection.id.Id))
    gserver.sendToAllClients(GMsg(kind: Kind_PlayerDisconnects, data: fgResPlayerDisconnects))

  for msg in gserver.server.messages:
    # Try to unpack
    var gmsg = fromFlatty(msg.data, GMsg)
    case gmsg.kind
    of Kind_KEEPALIVE:
      gserver.server.send(msg.conn, msg.data) # just send the keepalive back (contains timestamp for ping times)
    of Kind_PlayerConnected:
      gprint Kind_PlayerConnected
    of Kind_PlayerDisconnects:
      gprint Kind_PlayerDisconnects
      let entPlayer = gserver.players[msg.conn.id.Id]
      gserver.lock.acquire()
      gserver.reg.trigger(EvPlayerDisconnected(id: msg.conn.id.Id, entPlayer: entPlayer, reason: "Client send disconnect.", pgserver: unsafeAddr gserver))
      gserver.lock.release()
    of Kind_PlayerMoved:
      # gprint KindGReqPlayerMoved
      var req = fromFlatty(gmsg.data, GReqPlayerMoved)
      # gprint req
      ## Test vector.
      # if abs(req.vec.x) > 1 or abs(req.vec.y) > 1:
      #   echo "invalid move"
      #   # inform the "cheating" / desynced player
      # else:
      let entPlayer = gserver.players[msg.conn.id.Id]
      var compPlayer = gserver.reg.getComponent(entPlayer, CompPlayer)
      # gprint "Move: ", req.vec
      # compPlayer.controlBody.position = req.vec # Vect(x: req.vec.x, y: req.vec.y)
      # compPlayer.controlBody.position = req.controlBodyPos  #compPlayer.body.position + (req.moveVector * 10)
      # compPlayer.controlBody.position = compPlayer.body.position + (req.moveVector).normalize  # req.controlBodyPos  #compPlayer.body.position + (req.moveVector * 10)
      # compPlayer.controlBody.position = compPlayer.controlBody.position + (req.moveVector).normalize  # req.controlBodyPos  #compPlayer.body.position + (req.moveVector * 10)
      compPlayer.desiredPosition = req.controlBodyPos

      let serverClientDiff = (compPlayer.body.position - req.bodyPos)
      gprint serverClientDiff, serverClientDiff.length

      # compPlayer.controlBody.
      # compPlayer.controlBody.velocity = req.moveVector #* 100
      # compPlayer.controlBody.velocity = compPlayer.controlBody.position - compPlayer.body.position
      # gprint compPlayer.controlBody.velocity
      # compPlayer.controlBody.velocity = req.velocity
      # compPlayer.controlBody.position = req.vec.y
      # .pos += req.vec

      ## Not fast pasted
      # let res = GResPlayerMoved(playerId: msg.conn.id, pos: gserver.players[msg.conn.id].pos, moveId: req.moveId)
      # let fres = toFlatty(res)
      # for id, player in gserver.players:
      #   # if id != msg.conn.id:
      #   gserver.server.send(player.connection, toFlatty(GMsg(kind: KindGReqPlayerMoved, data: fres)))

    else:
      gprint "UNKNOWN"

    # echo "GOT MESSAGE: ", msg.data
    # echo message back to the client
    # server.send(msg.conn, "you said:" & msg.data)
    # server.send(msg.conn, "ok")
    if msg.data == "bye":
      gserver.server.disconnect(msg.conn)
    # server.disconnect(msg.conn)
  # Send position updates regardless of previous move TODO good?
  # gprint "fanout"
  for id, entPlayer in gserver.players:
    let compPlayer = gserver.reg.getComponent(entPlayer, CompPlayer)
    if compPlayer.map == WORLDMAP_ENTITY: continue
    # gprint entPlayer, compPlayer.body.position, compPlayer.controlBody.position, compPlayer.desiredPosition
    let res = GResPlayerMoved(playerId: id, pos: compPlayer.body.position, velocity: compPlayer.controlBody.velocity, moveId: -10)
    let fres = toFlatty(res)
    let gmsg = GMsg(kind: Kind_PlayerMoved, data: fres)
    gserver.sendToAllClientsOnMap(gmsg, compPlayer.map)


proc networkSystemThread(ptrgserver: ptr GServer) {.thread.} =
  var gserver = ptrgserver[]
  var dc = newDeltaCalculator(gserver.targetServerFps.int, timerAccuracy = -1)

  gserver.reg.connect(EvPlayerMovedToWorldmap,
    proc (ev: EvPlayerMovedToWorldmap) = echo ev
  )

  gserver.reg.connect(EvPlayerDisconnected,
    proc (ev: EvPlayerDisconnected) =
      gprint "[NETWORK THREAD] Player disconnected :", ev
  )

  while true:
    dc.startFrame()
    gserver.lock.acquire()
    mainNetworkTick(addr gserver, dc.delta)
    gserver.lock.release()
    dc.endFrame()
    dc.sleep()


proc doCli(gserver: GServer) =
  let ci = cli()
  case ci.kind
  of help:
    echo "HELP!!"
  # of "kickall":
  of players:
    gserver.lock.acquire()
    try:
      let store = gserver.reg.getStore(CompPlayer)
      echo "Players: ", store.len

      for (entPlayer, compPlayer) in gserver.reg.entitiesWithComp(CompPlayer):
        echo entPlayer, compPlayer[]
    except:
      echo getCurrentExceptionMsg()
    gserver.lock.release()
  of maps:
    gserver.lock.acquire()
    for worldmapPos, entMap in gserver.maps:
      let compMap = gserver.reg.getComponent(entMap, CompMap)
      print worldmapPos, entMap, compMap.players
    gserver.lock.release()
  of lock:
    gserver.lock.acquire()
  of unlock:
    gserver.lock.release()
  of tele:
    gserver.teleport(ci.teleEnt, ci.teleXX, ci.teleYY)
  of teleWorldmap:
    gserver.teleportWorldmap(ci.teleWorldmapEnt, ci.teleWorldmapXX, ci.teleWorldmapYY)
  of toWorldmap:
    gserver.movePlayerToWorldmap(ci.toWorldmapEnt)
  else:
    discard

proc cliLoop(gserver: GServer) =
  ## The info cliLoop.
  ## All the work is done in threads.
  while true:
    try:
      when defined(noCli):
        sleep(1000)
      else:
        gserver.doCli()
    except:
      echo getCurrentExceptionMsg()


var gserver = GServer()
gserver.players = initTable[Id, Entity]()
gserver.server = newReactor("0.0.0.0", 1999)
gserver.config = loadConfig(getAppDir() / "serverConfig.ini")
gserver.reg = newRegistry()
initLock(gserver.lock)
echo "Listenting for UDP on 127.0.0.1:1999"

gserver.systemMaps = gserver.newSystemMaps(unsafeAddr gserver)

gserver.configure()
createThread(gserver.physicThread, systemPhysicThread, addr gserver)
createThread(gserver.networkThread, networkSystemThread, addr gserver)
gserver.cliLoop()