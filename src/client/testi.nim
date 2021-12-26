
import typesClient
import systemDraw
import netlib
import ../shared/assetLoader
import nimraylib_now

import systemPhysic
import ../shared/cMap

const CLIENT_VERSION = 2


# var screenWidth = getScreenWidth() div 2
# var screenHeight = getScreenHeight() div 2

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
gclient.fsm = newFsm[ClientState](MAIN_MENU)
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

proc mainLoop(gclient: GClient) =
  # initPhysics()

  var idx = 0
  # var playerPos = Vector2(x: 10, y: 10) # TODO this could come from players with our user id
  var moved = false

  gclient.connect() ## Autoconnect for faster testing
  var circle: PhysicsBody # TODO test
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
        gclient.myPlayerId = res.playerId
        print gclient.myPlayerId
        # gclient.clientState = MAP
        gclient.fsm.transition(MAP)
        gclient.serverMessages.add("Connected to server yourId:" & $res.playerId)
        gclient.currentMap = gclient.newMap("assets/maps/demoTown.tmx")
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
        # gclient.destroyPlayer(entPlayer, disco.playerId)
        echo gclient.players
        gclient.reg.destroyEntity(entPlayer)
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
          # TODO test if this is good?
          compPlayer.controlBody.position = res.pos

          let diff = (compPlayer.controlBody.position - compPlayer.body.position)
          if diff.length().abs < 5:
            compPlayer.controlBody.velocity = vzero
          else:
            compPlayer.controlBody.velocity = (diff.normalize() * 100) #* delta

      else:
        discard

    for connection in gclient.nclient.newConnections:
      echo "[new] ", connection.address
    for connection in gclient.nclient.deadConnections:
      echo "[dead] ", connection.address
      gclient.serverMessages.add("Lost server connection")
      gclient.connected = false
      gclient.fsm.transition(MAIN_MENU)
      gclient.reg.destroyAll()

    # Key events
    if isKeyPressed(KeyboardKey.I):
      echo "I"

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
        vec: compPlayer.controlBody.position,
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

    gclient.systemPhysic(getFrameTime())
    gclient.systemDraw()
    gclient.reg.cleanup() # periodically remove invalidated entities

  closeWindow()


proc dummy(): Future[void] {.async.} =
  while true:
    await sleepAsync(1000)
asyncCheck dummy()
gclient.mainLoop()