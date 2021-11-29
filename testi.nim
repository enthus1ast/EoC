import math
import nimraylib_now
import shared
import json
import tables
import print

var screenWidth = 800
var screenHeight = 450
initWindow(screenWidth, screenHeight,
           "raylib [texture] example - texture rectangle")
##  NOTE: Textures MUST be loaded after Window initialization (OpenGL context is requiRed)

setTargetFPS(60)
##  Set our game to run at 60 frames-per-second
## --------------------------------------------------------------------------------------
##  Main game loop



###
# Network init
###
import netty, os, flatty

# create connection
var client = newReactor()
# connect to server
var c2s = client.connect("127.0.0.1", 1999)
# send message on the connection
# main loop
var idx = 0
var connected = true
# while connected:
#   sleep(250)

var players = initTable[Id, Vector2]()
var myIdIs: Id

proc sendKeepalive() =
    var gmsg = GMsg()
    gmsg.kind = KEEPALIVE
    gmsg.data = ""
    echo "send keepalive"
    client.send(c2s, toFlatty(gmsg))

var playerPos = Vector2(x: 10, y: 10)
var moved = false
while not windowShouldClose(): ##  Detect window close button or ESC key
  moved = false

  idx.inc
  # echo "."
  client.tick()
  # if idx mod 10 == 0:
  #   echo "send"
  #   client.send(c2s, "hi")
  # if idx == 200:

  # if idx == 200:
  #   echo "disco"
  #   client.send(c2s, "bye")
    # client.disconnect(c2s)
    # break
  # must call tick to both read and write
  # usually there are no new messages, but if there are
  # c2s.close()
  for msg in client.messages:
    # print message data
    echo "GOT MESSAGE: ", msg.data

    var gmsg = fromFlatty(msg.data, GMsg)
    case gmsg.kind
    od YOUR_ID_IS:

    of PLAYER_CONNECTED:
      # print PLAYER_CONNECTED
      let res = fromFlatty(gmsg.data, GResPlayerConnected)
      players[res.playerId] = Vector2(x: 10, y: 10)
    of PLAYER_DISCONNECTED:
      print PLAYER_DISCONNECTED
      let disco = fromFlatty(gmsg.data, GResPlayerDisconnects)
      print disco

      players.del(disco.playerId) # = res.pos

    of PLAYER_MOVED:
      let res = fromFlatty(gmsg.data, GResPlayerMoved)
      players[res.playerId] = res.pos
    else:
      discard




  for connection in client.newConnections:
    echo "[new] ", connection.address
  for connection in client.deadConnections:
    echo "[dead] ", connection.address
    connected = false



  # Key events
  if isKeyPressed(KeyboardKey.I):
    echo "I"
  # elif isKeyPressed(KeyboardKey.Left):
  #   echo "left"
  # if isKeyPressed(KeyboardKey.Up):
  #   echo "up"
  # elif isKeyPressed(KeyboardKey.Down):
  #   echo "down"

  # Key events
  if isKeyDown(KeyboardKey.D):
    # echo "right"
    playerPos.x += 2
    moved = true
  elif isKeyDown(KeyboardKey.A):
    # echo "left"
    playerPos.x -= 2
    moved = true

  if isKeyDown(KeyboardKey.W):
    # echo "up"
    playerPos.y -= 2
    moved = true

  elif isKeyDown(KeyboardKey.S):
    # echo "down"
    playerPos.y += 2
    moved = true



  ## Net
  if moved:
    var gmsg = GMsg()
    gmsg.kind = PLAYER_MOVED
    gmsg.data = toFlatty(playerPos)
    client.send(c2s, toFlatty(gmsg))

  if idx mod 60 == 0:
    sendKeepalive()

  beginDrawing()
  clearBackground(Raywhite)
  let mousePos = getMousePosition()
  # drawRectangle 500, 0, getScreenWidth() - 500, getScreenHeight(), fade(LIGHTGRAY, 0.3)
  # drawRectangle(5, 5, playerPos.x.int, playerPos.y.int, LIGHTGRAY)
  drawCircle(playerPos.x.int, playerPos.y.int, 5, LIGHTGRAY)
  drawCircle(mousePos.x.int, mousePos.y.int, 3, RED)

  # draw all other players
  for id, pos in players:
    drawCircle(pos.x.int, pos.y.int, 5, RED)


  drawText("FRAME SPEED: ", 165, 210, 10, Darkgray)

  endDrawing()

# unloadTexture(scarfy)
closeWindow()