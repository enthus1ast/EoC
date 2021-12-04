import typesClient
import systemDraw
import netlib
import assetLoader
import nimraylib_now

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
gclient.players = initTable[Id, Player]()
gclient.myPlayerId = 0
gclient.connected = false
gclient.moveid = 0
gclient.serverMessages = newChatbox(5)
gclient.camera = Camera2D(
  # target: (x: player.x + 20.0, y: player.y + 20.0),
  target: (0.0,0.0),
  offset: (x: screenWidth / 2, y: screenHeight / 2),
  rotation: 0.0,
  zoom: 1.0,
)
gclient.assets = newAssetLoader()

gclient.assets.loadTexture("assets/img/test.png")
gclient.assets.loadMap("assets/maps/demoTown.tmx")

## Loading sprites must be done after window initialization

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
        print res
        # if res.playerId != gclient.myPlayerId:
        var player = Player()
        player.id = res.playerId
        player.oldpos = res.pos # on connect set both equal
        player.pos = res.pos # on connect set both equal
        player.lastmove = getMonoTime()
        # gclient.players[res.playerId].pos = res.pos # TODO
        gclient.players[res.playerId] = player
      of Kind_PlayerDisconnects:
        print Kind_PlayerDisconnects
        let disco = fromFlatty(gmsg.data, GResPlayerDisconnects)
        print disco
        gclient.players.del(disco.playerId) # = res.pos
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
              gclient.myPlayer().pos = res.pos
              # gclient.players[res.playerId] = res.pos
              gclient.moves = initTable[int32, Vector2]()
            discard
        else:
          ## A move for other players / crit
          gclient.players[res.playerId].oldpos = gclient.players[res.playerId].pos
          gclient.players[res.playerId].pos = res.pos # TODO
          gclient.players[res.playerId].lastmove = getMonoTime()


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



    ## Net
    if moved:
      gclient.moveId.inc
      var gmsg = GMsg()
      gmsg.kind = Kind_PlayerMoved
      let gReqPlayerMoved = GReqPlayerMoved(moveId: gclient.moveId, vec: moveVector)

      # Client prediction set position even if not aknowleged
      gclient.myPlayer().pos += moveVector

      gmsg.data = toFlatty(gReqPlayerMoved)
      gclient.nclient.send(gclient.c2s, toFlatty(gmsg))
      # gclient.moves[gclient.moveId] = gReqPlayerMoved
      gclient.moves[gclient.moveId] = gclient.myPlayer().pos


    if gclient.clientState == CONNECTING or gclient.clientState == MAP: ## TODO
      if idx mod 60 == 0:
        gclient.sendKeepalive()


    gclient.systemDraw()


  closePhysics()
  closeWindow()


proc dummy(): Future[void] {.async.} =
  while true:
    await sleepAsync(1000)
asyncCheck dummy()
gclient.mainLoop()