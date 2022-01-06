
import typesClient
import systemDraw
import netlib
import ../shared/assetLoader
import nimraylib_now

import systemPhysic
import ../shared/cMap
import ../shared/cSimpleDoor
import ../shared/cAnimation
import ../shared/cPlayer
import ../shared/cHealth

const CLIENT_VERSION = 3
# const IN_CLIENT = true
# const IN_SERVER = false

var screenWidth = 800
var screenHeight = 450
setConfigFlags(VsyncHint or Msaa4xHint or WindowHighdpi or WindowResizable)
initWindow(screenWidth, screenHeight, "EoC")

setTargetFPS(60)

var gclient = GClient()
gclient.nclient = newReactor()
gclient.players = initTable[Id, Entity]()
gclient.myPlayerId = 0.Id
gclient.connected = false
gclient.moveid = 0
gclient.serverMessages = newChatbox(5)
gclient.assets = newAssetLoader()
gclient.debugDraw = true
gclient.reg = newRegistry()
gclient.physic = newSystemPhysic(gclient)
gclient.draw = newSystemDraw()
gclient.fsm = newFsm[ClientState](MAIN_MENU)
gclient.fsm.allowTransition(MAIN_MENU, CONNECTING)
gclient.fsm.allowTransition(CONNECTING, MAP)
gclient.fsm.allowTransition(MAP, WORLD_MAP)
gclient.fsm.allowTransition(WORLD_MAP, MAP)

proc load(gclient: GClient) =
  ## Loads all the assets
  echo "[+] loading!"
  gclient.assets.loadTexture("assets/img/empty.png", "empty")
  gclient.assets.loadTexture("assets/img/doorBlock.png", "doorBlock")
  gclient.assets.loadTexture("assets/img/test.png")
  gclient.assets.loadMap("assets/maps/demoTown.tmx")
  gclient.assets.loadSpriteSheet("assets/img/laserDing/laserDing.png", "laserDing")
  echo gclient.assets.textures

gclient.load()

proc transAllToMainMenu[S](fsm: Fsm[S], fromS, toS: S) =
  ## Transists from all states to the main menu,
  ## here we do cleanup, so that the game client is as fresh as possible for a new connection
  gclient.serverMessages.add("Lost server connection")
  if gclient.connected:
    gclient.disconnect() # TODO check if disconnect is needed here.
  gclient.connected = false
  gclient.reg.invalidateAll()
gclient.fsm.registerTransition(CONNECTING, MAIN_MENU, transAllToMainMenu[ClientState])
gclient.fsm.registerTransition(MAP, MAIN_MENU, transAllToMainMenu[ClientState])
gclient.fsm.registerTransition(WORLD_MAP, MAIN_MENU, transAllToMainMenu[ClientState])
gclient.fsm.registerTransition(MAIN_MENU, MAIN_MENU, transAllToMainMenu[ClientState])

## Loading sprites must be done after window initialization

# Main Menu
## TODO THIS IS STUPID
gclient.txtServer = cast[cstring](alloc(512)) #newString(1024)
var txtServerDefault = "127.0.0.1"
copyMem(addr gclient.txtServer[0], addr txtServerDefault[0], txtServerDefault.len)

# proc recv[T](gclient: GClient): T =
#   discard

# proc send[T](gclient: GClient, obj: T) =
#   discard

proc netMovePlayer(gclient: GClient, res: GResPlayerMoved) =
  # let entPlayer = gclient.myPlayer()
  let entPlayer = gclient.players[res.playerId]
  var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
  compPlayer.controlBody.velocity = res.velocity
  compPlayer.controlBody.position = res.pos


  # compPlayer.oldpos = compPlayer.pos
  # compPlayer.pos = res.pos # TODO
  # compPlayer.lastmove = getMonoTime()
  # # TODO test if this is good?
  # compPlayer.controlBody.position = res.pos

  if res.playerId == gclient.myPlayerId:
    # It is one move from us.
    # We look in our stored moves
    # and remove the good moves
    # if there is a bad move, or server correction, or the offset is too big
    # we replay the


    ## TODO can we still do GOOD or BAD move?
    ## for now lets try to hard set the players position when we desync
    # let entPlayer = gclient.myPlayer()
    # var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
    # compPlayer.controlBody.velocity = res.velocity
    # compPlayer.controlBody.position = res.pos
    # compPlayer.body.position = res.pos
    block:
      let diff = (compPlayer.body.position - res.pos)
      if diff.length().abs > 100: # TODO what is a good value?
        echo "[!!] Body is totally off, reset position hard!"
        compPlayer.body.position = res.pos

    # if gclient.moves.hasKey(res.moveId):
    #   if gclient.moves[res.moveId] == res.pos:
    #     echo "Move is good"
    #     gclient.moves.del(res.moveId)
    #   else:
    #     print "move is bad:", res, gclient.moves[res.moveId]
    #     echo "SERVER:", res.pos
    #     echo "LOCAL :", gclient.moves[res.moveId]
    #     ## TODO replay moves
    #     ## TODO currently we just reset
    #     let entPlayer = gclient.myPlayer()
    #     var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
    #     compPlayer.pos = res.pos
    #     # gclient.players[res.playerId] = res.pos
    #     gclient.moves = initTable[int32, Vector2]()
    #   discard


  else:
    ## A move for other players / crit
    let entPlayer = gclient.players[res.playerId]
    var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
    compPlayer.oldpos = compPlayer.pos
    compPlayer.pos = res.pos # TODO
    compPlayer.lastmove = getMonoTime()
    # TODO test if this is good?
    compPlayer.controlBody.position = res.pos

    let diff = (compPlayer.controlBody.position - compPlayer.body.position)
    if diff.length().abs < 5:
      compPlayer.controlBody.velocity = vzero
    else:
      compPlayer.controlBody.velocity = (diff.normalize() * 100) #* delta

proc mainLoop(gclient: GClient) =
  # initPhysics()

  var idx = 0
  # var playerPos = Vector2(x: 10, y: 10) # TODO this could come from players with our user id
  var moved = false

  # gclient.connect() ## Autoconnect for faster testing
  while not windowShouldClose(): ##  Detect window close button or ESC key
    poll(1)

    moved = false
    idx.inc
    gclient.nclient.tick()
    for msg in gclient.nclient.messages:
      # echo "GOT MESSAGE: ", msg.data
      var gmsg = fromFlatty(msg.data, GMsg)
      case gmsg.kind
      of Kind_ServerInfo:
        let res = fromFlatty(gmsg.data, GResServerInfo)
        gclient.players.clear()
        gclient.targetServerFps = res.targetServerFps
        if res.serverVersion != CLIENT_VERSION:
          gclient.serverMessages.add("CLient does not match server version.", "client")
          print res.serverVersion, CLIENT_VERSION
          gclient.disconnect()
      of Kind_YourIdIs:
        let res = fromFlatty(gmsg.data, GResYourIdIs)
        gclient.connected = true
        gclient.myPlayerId = res.playerId
        print gclient.myPlayerId
        gclient.fsm.transition(MAP)
        gclient.serverMessages.add("Connected to server yourId:" & $res.playerId)
        gclient.currentMap = gclient.newMap("assets/maps/demoTown.tmx", gclient.physic.space)

        # DEMO Door
        # discard gclient.newVerySimpleDoor(Vector2(x: 0.0, y: 0.0), gclient.physic.space)
        # discard gclient.newVerySimpleDoor(Vector2(x: 1.0, y: 6.0), gclient.physic.space)
        # discard gclient.newVerySimpleDoor(Vector2(x: 1.0, y: 7.0), gclient.physic.space)
        # discard gclient.newVerySimpleDoor(Vector2(x: 1.0, y: 8.0), gclient.physic.space)
        # discard gclient.newVerySimpleDoor(Vector2(x: 1.0, y: 9.0), gclient.physic.space)

      of Kind_KEEPALIVE:
        let res = fromFlatty(gmsg.data, MonoTime)
        #echo "Ping (with server delay!): ", (getMonoTime() - res).inMilliseconds - calculateFrameTime(gclient.targetServerFps)
      of Kind_PlayerConnected:
        print Kind_PlayerConnected
        let res = fromFlatty(gmsg.data, GResPlayerConnected)

        var hasCollision = res.playerId == gclient.myPlayerId
        var entPlayer = gclient.newPlayer(res.playerId, res.pos, "Player's Name TODO", hasCollision = hasCollision)
        gclient.players[res.playerId] = entPlayer
      of Kind_PlayerWorldmap:
        let res = fromFlatty(gmsg.data, GResPlayerWorldmap)
        print res
        if res.playerId == gclient.myPlayerId:
          gclient.fsm.transition(WORLD_MAP)
        else:
          let entPlayer = gclient.players[res.playerId]
          # gclient.reg.invalidateEntity(entPlayer)
          gclient.reg.destroyEntity(entPlayer)

      of Kind_PlayerDisconnects:
        print Kind_PlayerDisconnects
        let disco = fromFlatty(gmsg.data, GResPlayerDisconnects)
        print disco
        let entPlayer = gclient.players[disco.playerId]
        # gclient.destroyPlayer(entPlayer, disco.playerId)
        echo gclient.players
        # gclient.reg.invalidateEntity(entPlayer)
        gclient.reg.destroyEntity(entPlayer)
        # gclient.players.del(disco.playerId)
        print gclient.players
      of Kind_PlayerMoved:
        # print "moved"
        let res = fromFlatty(gmsg.data, GResPlayerMoved)

        if not gclient.players.hasKey(res.playerId):
          print "Server wants me to move an unknown player!", res.playerId
        else:
          gclient.netMovePlayer(res)


      else:
        discard

    for connection in gclient.nclient.newConnections:
      echo "[new] ", connection.address
    for connection in gclient.nclient.deadConnections:
      echo "[dead] ", connection.address
      gclient.fsm.transition(MAIN_MENU)

    # Key events
    if isKeyPressed(KeyboardKey.I):
      echo "I"

    if isKeyPressed(KeyboardKey.Q):
      gclient.fsm.transition(MAIN_MENU)

    if isKeyPressed(KeyboardKey.O):
      gclient.debugDraw = not gclient.debugDraw

    # if isKeyPressed(KeyboardKey.L):
    #   gclient.reg.destroyEntity(gclient.currentMap)

    if isKeyPressed(KeyboardKey.M):
      if gclient.fsm.state == MAP:
        gclient.fsm.transition(WORLD_MAP)
      elif gclient.fsm.state == WORLD_MAP:
        gclient.fsm.transition(MAP)

    if isKeyPressed(KeyboardKey.F11):
      toggleFullscreen()

    var moveVector: Vector2


    ## Key input for the map
    if gclient.fsm.state == MAP:


      ## Cheats for testing
      if isKeyPressed(KeyboardKey.C):
        # disable player collision
        let playerEnt = gclient.myPlayer()
        let compPlayer = gclient.reg.getComponent(playerEnt, CompPlayer)
        compPlayer.shape.filter = SHAPE_FILTER_NONE
      if isKeyPressed(KeyboardKey.V):
        # enable player collision
        let playerEnt = gclient.myPlayer()
        let compPlayer = gclient.reg.getComponent(playerEnt, CompPlayer)
        compPlayer.shape.filter = ShapeFilter(group: nil, categories: 4294967295'u32, mask: 4294967295'u32)
      if isKeyPressed(KeyboardKey.B):
        # disable ALL player collision
        for playerEnt in gclient.players.values:
          let compPlayer = gclient.reg.getComponent(playerEnt, CompPlayer)
          compPlayer.shape.filter = SHAPE_FILTER_NONE
      if isKeyPressed(KeyboardKey.N):
        # enable ALL player collision
        for playerEnt in gclient.players.values:
          let compPlayer = gclient.reg.getComponent(playerEnt, CompPlayer)
          compPlayer.shape.filter = ShapeFilter(group: nil, categories: 4294967295'u32, mask: 4294967295'u32)

      if isKeyPressed(KeyboardKey.J):
        # OPEN OR CLOSE ALL DOORS
        for entDoor in gclient.reg.entities(CompVerySimpleDoor):
          gclient.openDoor(entDoor, open = true)
      if isKeyPressed(KeyboardKey.K):
        # OPEN OR CLOSE ALL DOORS
        for entDoor in gclient.reg.entities(CompVerySimpleDoor):
          gclient.openDoor(entDoor, open = false)


      # Key events
      if isKeyDown(KeyboardKey.D):
        # echo "right"
        # playerPos.x += 2
        moveVector.x = 1
        moved = true
      elif isKeyDown(KeyboardKey.A):
        # echo "left"
        # playerPos.x -= 2
        moveVector.x = -1
        moved = true

      if isKeyDown(KeyboardKey.W):
        # echo "up"
        # playerPos.y -= 2
        moveVector.y = -1
        moved = true

      elif isKeyDown(KeyboardKey.S):
        # echo "down"
        # playerPos.y += 2
        moveVector.y = 1
        moved = true

      if isKeyDown(KeyboardKey.L): ## TODO remove this; simulates a HACK
        moveVector.y *= 2 ## TODO remove this; simulates a HACK
        moveVector.x *= 2 ## TODO remove this; simulates a HACK

      if (gclient.myPlayerId != 0.Id) and (not moved): # and moveVector.length > 0:
        # TODO this whole block must be gone
        let entPlayer = gclient.myPlayer()
        let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
        compPlayer.controlBody.position = compPlayer.body.position
        compPlayer.controlBody.velocity = vzero


      # # TODO STUPID
      # var gmsg = GMsg()
      # gmsg.kind = Kind_PlayerMoved
      # let gReqPlayerMoved = GReqPlayerMoved(
      #   moveId: gclient.moveId,
      #   vec: compPlayer.controlBody.position,
      #   controlBodyPos: compPlayer.controlBody.position,
      #   moveVector: moveVector,
      #   velocity: compPlayer.controlBody.velocity
      # )
      # gmsg.data = toFlatty(gReqPlayerMoved)
      # gclient.nclient.send(gclient.c2s, toFlatty(gmsg))


      if (gclient.myPlayerId != 0.Id):
        let entPlayer = gclient.myPlayer()
        let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
        compPlayer.pos = compPlayer.body.position
    #   moveVector = (0.0, 0.0)
    #   let entPlayer = gclient.myPlayer()
    #   let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
    #   # echo "stop"
    #   compPlayer.body.velocity = moveVector
    # let entPlayer = gclient.myPlayer()
    # let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
    # compPlayer.pos = compPlayer.body.position
    ## Net
    if moved:
      gclient.moveId.inc

      # Client prediction set position even if not aknowleged
      let entPlayer = gclient.myPlayer()
      let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
      # compPlayer.pos += moveVector # TODO original one
      # compPlayer.pos = compPlayer.body.position


      ## PHYSIC DEBUG
      # compPlayer.body.applyImpulseAtLocalPoint(moveVector * 1000 * getFrameTime()  , v(0.0, 0.0))
      # compPlayer.body.velocity = moveVector * 100

      # compPlayer.controlBody.position = compPlayer.body.position + (moveVector * 100)
      compPlayer.controlBody.position = compPlayer.body.position + (moveVector)
      # compPlayer.controlBody.velocity = moveVector * 100 # TODO GOOD?
      compPlayer.controlBody.velocity = (compPlayer.controlBody.position - compPlayer.body.position) * 100  # moveVector * 100
      # compPlayer.body.

      var gmsg = GMsg()
      gmsg.kind = Kind_PlayerMoved
      let gReqPlayerMoved = GReqPlayerMoved(
        moveId: gclient.moveId,
        # vec: moveVector
        bodyPos: compPlayer.body.position,
        controlBodyPos: compPlayer.controlBody.position,
        moveVector: moveVector,
        velocity: compPlayer.controlBody.velocity
      )

      gmsg.data = toFlatty(gReqPlayerMoved)
      gclient.nclient.send(gclient.c2s, toFlatty(gmsg))
      # gclient.moves[gclient.moveId] = gReqPlayerMoved
      gclient.moves[gclient.moveId] = compPlayer.pos
    else:
      ## PHYSIC DEBUG
      # let entPlayer = gclient.myPlayer()
      # let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
      # compPlayer.controlBody.position = compPlayer.body.position
      # compPlayer.body.velocity = v(0,0)

    if gclient.fsm.state == CONNECTING or gclient.fsm.state == MAP: ## TODO?
      if idx mod 60 == 0:
        gclient.sendKeepalive()

    gclient.systemHealth(getFrameTime())
    gclient.systemPhysic(getFrameTime())
    gclient.systemAnimation(getFrameTime())
    gclient.systemDraw()
    gclient.reg.cleanup() # periodically remove invalidated entities

  closeWindow()


proc dummy(): Future[void] {.async.} =
  while true:
    await sleepAsync(1000)
asyncCheck dummy()
gclient.mainLoop()