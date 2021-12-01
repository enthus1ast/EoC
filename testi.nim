import math
import nimraylib_now
import shared
import json
import tables
import print
import strformat

var screenWidth = 800
var screenHeight = 450
initWindow(screenWidth, screenHeight,
           "raylib [texture] example - texture rectangle")
##  NOTE: Textures MUST be loaded after Window initialization (OpenGL context is requiRed)

setTargetFPS(60)
import netty, os, flatty

type
  GClient = ref object
    nclient: Reactor
    clientState: ClientState
    c2s: Connection
    players: Table[Id, Vector2]
    myPlayerId: Id
    connected: bool

    # Main Menu
    txtServer: cstring
    moveId: int32
    # moves: Table[int32, GReqPlayerMoved]
    moves: Table[int32, Vector2]


var gclient = GClient()
gclient.clientState = MAIN_MENU # we start in the main menu
gclient.nclient = newReactor()
gclient.players = initTable[Id, Vector2]()
gclient.myPlayerId = 0
gclient.connected = false
gclient.moveid = 0

# Main Menu
## TODO THIS IS STUPID
gclient.txtServer = cast[cstring](alloc(512)) #newString(1024)
var txtServerDefault = "127.0.0.1"
copyMem(addr gclient.txtServer[0], addr txtServerDefault[0], txtServerDefault.len)


proc connect(gclient: GClient, host: string = "127.0.0.1", port: int = 1999) =
  gclient.clientState = CONNECTING
  gclient.c2s = gclient.nclient.connect(host, port)

proc sendKeepalive(gclient: GClient) =
    var gmsg = GMsg()
    gmsg.kind = KEEPALIVE
    gmsg.data = ""
    # echo "send keepalive"
    gclient.nclient.send(gclient.c2s, toFlatty(gmsg))

# proc recv[T](gclient: GClient): T =
#   discard
# proc send[T](gclient: GClient, obj: T) =
#   discard

proc mainLoop(gclient: GClient) =
  initPhysics()

  var idx = 0
  var playerPos = Vector2(x: 10, y: 10) # TODO this could come from players with our user id
  var moved = false

  gclient.connect() ## Autoconnect for faster testing


  while not windowShouldClose(): ##  Detect window close button or ESC key
    moved = false
    idx.inc
    gclient.nclient.tick()
    for msg in gclient.nclient.messages:
      # echo "GOT MESSAGE: ", msg.data

      var gmsg = fromFlatty(msg.data, GMsg)
      case gmsg.kind
      of YOUR_ID_IS:
        let res = fromFlatty(gmsg.data, GResYourIdIs)
        gclient.myPlayerId = res.playerId
        gclient.clientState = MAP
      of PLAYER_CONNECTED:
        # print PLAYER_CONNECTED
        let res = fromFlatty(gmsg.data, GResPlayerConnected)
        if res.playerId != gclient.myPlayerId:
          gclient.players[res.playerId] = res.pos
      of PLAYER_DISCONNECTED:
        print PLAYER_DISCONNECTED
        let disco = fromFlatty(gmsg.data, GResPlayerDisconnects)
        print disco
        gclient.players.del(disco.playerId) # = res.pos
      of PLAYER_MOVED:
        let res = fromFlatty(gmsg.data, GResPlayerMoved)
        gclient.players[res.playerId] = res.pos
        if res.playerId == gclient.myPlayerId:
          # It is one move from us.
          # We look in our stored moves
          # and remove the good moves
          # if there is a bad move, or server correction, or the offset is too big
          # we replay the
          if gclient.moves.hasKey(res.moveId):
            if gclient.moves[res.moveId] == res.pos:
              # echo "Move is good"
              gclient.moves.del(res.moveId)
            else:
              print "move is bad:", res, gclient.moves[res.moveId]
              echo "SERVER:", res.pos
              echo "LOCAL :", gclient.moves[res.moveId]
              ## TODO replay moves
              ## TODO currently we just reset
              playerPos = res.pos
              # gclient.players[res.playerId] = res.pos
              gclient.moves = initTable[int32, Vector2]()
            discard


      else:
        discard

    for connection in gclient.nclient.newConnections:
      echo "[new] ", connection.address
    for connection in gclient.nclient.deadConnections:
      echo "[dead] ", connection.address
      gclient.connected = false
      gclient.clientState = MAIN_MENU

    # Key events
    if isKeyPressed(KeyboardKey.I):
      echo "I"

    var moveVector: Vector2

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
      gmsg.kind = PLAYER_MOVED
      let gReqPlayerMoved = GReqPlayerMoved(moveId: gclient.moveId, vec: moveVector)

      # Client prediction set position even if not aknowleged
      playerPos += moveVector

      gmsg.data = toFlatty(gReqPlayerMoved)
      gclient.nclient.send(gclient.c2s, toFlatty(gmsg))
      # gclient.moves[gclient.moveId] = gReqPlayerMoved
      gclient.moves[gclient.moveId] = playerPos


    if gclient.clientState == CONNECTING or gclient.clientState == MAP: ## TODO
      if idx mod 60 == 0:
        gclient.sendKeepalive()

    beginDrawing()

    case gclient.clientState
    of MAIN_MENU:
      clearBackground(Yellow)
      # if (GuiTextBox((Rectangle){ 25, 215, 125, 30 }, textBoxText, 64, textBoxEditMode)) textBoxEditMode = !textBoxEditMode;
      # proc textBox*(bounds: Rectangle; text: cstring; textSize: cint; editMode: bool): bool
      # var text: cstring
      # if text.isNil:
      #   text = newString(512)
      if textBox(Rectangle(x: 10, y:10, width:150, height:30), gclient.txtServer , textSize = 512, editMode = true):
        echo "TEXT BOX:", gclient.txtServer

      var btnConnect = button(Rectangle(x: 10, y:50, width:50, height:30), "Connect")
      if btnConnect:
        echo "CONNECT"
        gclient.connect($gclient.txtServer)
    of CONNECTING:
      clearBackground(Red)
      let text = fmt"Connecting to server: {gclient.txtServer}"
      drawText(text, 10, 10, 20, Black)
    of MAP:
      clearBackground(Raywhite)
      let mousePos = getMousePosition()
      drawCircle(playerPos.x.int, playerPos.y.int, 5, LIGHTGRAY)
      drawCircle(mousePos.x.int, mousePos.y.int, 3, RED)
      # draw all other players
      for id, pos in gclient.players:
        drawCircle(pos.x.int, pos.y.int, 5, RED)
      # drawText("FRAME SPEED: ", 165, 210, 10, Darkgray)
      drawText("Unacknowledged moves: " & $gclient.moves.len , 10, 10, 10, Darkgray)
    endDrawing()

  closePhysics()
  closeWindow()

gclient.mainLoop()