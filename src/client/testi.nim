
import typesClient
import systemDraw
import netlib
import assetLoader
import nimraylib_now

import systemPhysic

const CLIENT_VERSION = 2





# var screenWidth = getScreenWidth() div 2
# var screenHeight = getScreenHeight() div 2

var screenWidth = 800
var screenHeight = 450
setConfigFlags(VsyncHint or Msaa4xHint or WindowHighdpi or WindowResizable)
initWindow(screenWidth, screenHeight, "EoC")

setTargetFPS(60)

var gclient = GClient()
gclient.clientState = MAIN_MENU # we start in the main menu
gclient.nclient = newReactor()
gclient.players = initTable[Id, Entity]()
gclient.myPlayerId = 0
gclient.connected = false
gclient.moveid = 0
gclient.serverMessages = newChatbox(5)
gclient.camera = Camera2D(
  target: (0.0,0.0),
  offset: (x: screenWidth / 2, y: screenHeight / 2),
  rotation: 0.0,
  zoom: 1.0,
)
gclient.assets = newAssetLoader()
gclient.assets.loadTexture("assets/img/test.png")
gclient.assets.loadMap("assets/maps/demoTown.tmx")
gclient.debugDraw = true
gclient.reg = newRegistry()
gclient.physic = newSystemPhysic()
## Loading sprites must be done after window initialization



## Some components
# type
#   CompPlayer = ref object of Component
#     playerId: Id
#     name: string




# Main Menu
## TODO THIS IS STUPID
gclient.txtServer = cast[cstring](alloc(512)) #newString(1024)
var txtServerDefault = "127.0.0.1"
copyMem(addr gclient.txtServer[0], addr txtServerDefault[0], txtServerDefault.len)


# gclient.circle = createPhysicsBodyCircle((screenWidth.float/2.0, screenHeight.float/2.0), 45.0, 10.0)

# proc recv[T](gclient: GClient): T =
#   discard

# proc send[T](gclient: GClient, obj: T) =
#   discard

# proc drawPlayer(gclient: GClient, player: Player) =
#   if player.id == gclient.myPlayerId:


converter toChipmunksVector(vec: Vector2): Vect =
  result.x = vec.x
  result.y = vec.y

proc mainLoop(gclient: GClient) =
  initPhysics()

  var idx = 0
  # var playerPos = Vector2(x: 10, y: 10) # TODO this could come from players with our user id
  var moved = false

  gclient.connect() ## Autoconnect for faster testing
  var circle: PhysicsBody # TODO test
  while not windowShouldClose(): ##  Detect window close button or ESC key
    poll(1)

    # updatePhysics()

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
        gclient.myPlayerId = res.playerId
        print gclient.myPlayerId
        gclient.clientState = MAP
        gclient.serverMessages.add("Connected to server yourId:" & $res.playerId)
      of Kind_PlayerConnected:
        print Kind_PlayerConnected
        let res = fromFlatty(gmsg.data, GResPlayerConnected)
        var entPlayer = gclient.newPlayer(res.playerId, res.pos, "Player's Name TODO")
        gclient.players[res.playerId] = entPlayer
      of Kind_PlayerDisconnects:
        print Kind_PlayerDisconnects
        let disco = fromFlatty(gmsg.data, GResPlayerDisconnects)
        print disco
        let entPlayer = gclient.players[disco.playerId]
        gclient.destroyPlayer(entPlayer, disco.playerId)
        # gclient.reg.destroyEntity(entPlayer)
        # gclient.players.del(disco.playerId)
        print gclient.players
      of Kind_PlayerMoved:
        # print "moved"
        let res = fromFlatty(gmsg.data, GResPlayerMoved)
        if res.playerId == gclient.myPlayerId:
          # It is one move from us.
          # We look in our stored moves
          # and remove the good moves
          # if there is a bad move, or server correction, or the offset is too big
          # we replay the
          if gclient.moves.hasKey(res.moveId):
            if gclient.moves[res.moveId] == res.pos:
              echo "Move is good"
              gclient.moves.del(res.moveId)
            else:
              print "move is bad:", res, gclient.moves[res.moveId]
              echo "SERVER:", res.pos
              echo "LOCAL :", gclient.moves[res.moveId]
              ## TODO replay moves
              ## TODO currently we just reset
              let entPlayer = gclient.myPlayer()
              var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
              compPlayer.pos = res.pos
              # gclient.players[res.playerId] = res.pos
              gclient.moves = initTable[int32, Vector2]()
            discard
        else:
          ## A move for other players / crit
          let entPlayer = gclient.players[res.playerId]
          var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
          compPlayer.oldpos = compPlayer.pos
          compPlayer.pos = res.pos # TODO
          compPlayer.lastmove = getMonoTime()


      else:
        discard

    for connection in gclient.nclient.newConnections:
      echo "[new] ", connection.address
    for connection in gclient.nclient.deadConnections:
      echo "[dead] ", connection.address
      gclient.serverMessages.add("Lost server connection")
      gclient.connected = false
      gclient.clientState = MAIN_MENU

    # Key events
    if isKeyPressed(KeyboardKey.I):
      echo "I"

    if isKeyPressed(KeyboardKey.O):
      gclient.debugDraw = not gclient.debugDraw

    if isKeyPressed(KeyboardKey.M):
      if gclient.clientState == MAP:
        gclient.clientState = WORLD_MAP
      elif gclient.clientState == WORLD_MAP:
        gclient.clientState = MAP

    if isKeyPressed(KeyboardKey.F11):
      toggleFullscreen()

    var moveVector: Vector2


    ## Key input for the map
    if gclient.clientState == MAP:
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

    if (gclient.myPlayerId != 0) and (not moved): # and moveVector.length > 0:
      ## TODO this whole block must be gone
      moveVector = (0.0, 0.0)
      let entPlayer = gclient.myPlayer()
      let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
      # echo "stop"
      compPlayer.body.velocity = moveVector


    ## Net
    if moved:
      gclient.moveId.inc
      var gmsg = GMsg()
      gmsg.kind = Kind_PlayerMoved
      let gReqPlayerMoved = GReqPlayerMoved(moveId: gclient.moveId, vec: moveVector)

      # Client prediction set position even if not aknowleged
      let entPlayer = gclient.myPlayer()
      let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
      compPlayer.pos += moveVector


      ## PHYSIC DEBUG
      # compPlayer.body.applyImpulseAtLocalPoint(moveVector, v(0.0, 0.0))
      compPlayer.body.velocity = moveVector * 100


      gmsg.data = toFlatty(gReqPlayerMoved)
      gclient.nclient.send(gclient.c2s, toFlatty(gmsg))
      # gclient.moves[gclient.moveId] = gReqPlayerMoved
      gclient.moves[gclient.moveId] = compPlayer.pos
    else:
      ## PHYSIC DEBUG
      # let entPlayer = gclient.myPlayer()
      # let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
      # compPlayer.body.velocity = v(0,0)

    if gclient.clientState == CONNECTING or gclient.clientState == MAP: ## TODO
      if idx mod 60 == 0:
        gclient.sendKeepalive()


    let delta = 1/60 # TODO
    gclient.systemPhysic(delta)
    gclient.systemDraw()

    gclient.reg.cleanup()

  closePhysics()
  closeWindow()


proc dummy(): Future[void] {.async.} =
  while true:
    await sleepAsync(1000)
asyncCheck dummy()
gclient.mainLoop()