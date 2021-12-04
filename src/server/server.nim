import netty
import print
import os
import ../shared
import flatty
import tables
import nimraylib_now/mangled/raylib # Vector2
import nimraylib_now/mangled/raymath # Vector2
import std/monotimes
import std/times
import std/parsecfg
import std/strutils
import std/random
import asyncdispatch

const SERVER_VERSION = 2

type
  Player = object
    id: Id
    connection: Connection
    pos: Vector2
  GServer = ref object
    players: Table[Id, Player]
    server: Reactor
    config: Config
    targetServerFps: uint8

var gserver = GServer()
gserver.players = initTable[Id, Player]()
gserver.server = newReactor("127.0.0.1", 1999)
gserver.config = loadConfig(getAppDir() / "serverConfig.ini")
echo "Listenting for UDP on 127.0.0.1:1999"

func configure(gserver: GServer) =
  gserver.targetServerFps = gserver.config.getSectionValue("net", "targetServerFps").parseInt().uint8

proc dumpConnectedPlayers(gserver: GServer) =
  echo "Connected players: ", gserver.players.len
  for id, player in gserver.players:
    print id, player.pos

proc sendToAllClients*(gserver: GServer, gmsg: GMsg) =
  ## Sends a `GMsg` to all clients connected to the server
  let msg = toFlatty(gmsg)
  for id, player in gserver.players:
    gserver.server.send(player.connection, msg)

proc genServerInfo(gserver: GServer): GResServerInfo =
  GResServerInfo(
    targetServerFps: gserver.targetServerFps,
    serverVersion: SERVER_VERSION
  )

proc main(gserver: GServer, delta: float) =
  # sleep(250)
  # sleep(10)
  # must call tick to both read and write
  # usually there are no new messages, but if there are
  # echo "tick"
  gserver.server.tick()
  for connection in gserver.server.newConnections:
    echo "[new] ", connection.address

    var player = Player()
    player.id = connection.id
    player.connection = connection
    player.pos = Vector2(x: (rand(50) + 20).float, y: (rand(50) + 20).float) # TODO
    gserver.players[connection.id] = player

    gserver.dumpConnectedPlayers()

    # send the new connecting player the server info
    let fGResServerInfo = toFlatty(gserver.genServerInfo())
    gserver.server.send(connection, toFlatty(GMsg(kind: Kind_ServerInfo, data: fGResServerInfo)))

    # send the new connecting player his id
    let fgResYourIdIs = toFlatty(GResYourIdIs(playerId: connection.id))
    gserver.server.send(connection, toFlatty(GMsg(kind: Kind_YourIdIs, data: fgResYourIdIs)))

    # update the new connected player about all the other players
    # let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    # server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))
    for id, player in gserver.players:
      if id != connection.id:
        let res = GResPlayerConnected(playerId: id, pos: player.pos)
        let fres = toFlatty(res)
        gserver.server.send(connection, toFlatty(GMsg(kind: Kind_PlayerConnected, data: fres)))


    # tell every other player about the new connected player
    let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id, pos: player.pos))
    for player in gserver.server.connections:
      # server.send(player, "Player connected:" & $connection.id)
      gserver.server.send(player, toFlatty(GMsg(kind: Kind_PlayerConnected, data: fgResPlayerConnected)))


  for connection in gserver.server.deadConnections:
    print "[dead] ", connection.address, connection.id
    gserver.players.del(connection.id)
    gserver.dumpConnectedPlayers()
    let fgResPlayerDisconnects = toFlatty(GResPlayerDisconnects(playerId: connection.id))
    gserver.sendToAllClients(GMsg(kind: Kind_PlayerDisconnects, data: fgResPlayerDisconnects))




  for msg in gserver.server.messages:

    # Try to unpack
    var gmsg = fromFlatty(msg.data, GMsg)
    case gmsg.kind
    of Kind_KEEPALIVE:
      discard
    of Kind_PlayerConnected:
      print Kind_PlayerConnected
    of Kind_PlayerDisconnects:
      print Kind_PlayerDisconnects
    of Kind_PlayerMoved:
      # print KindGReqPlayerMoved
      var req = fromFlatty(gmsg.data, GReqPlayerMoved)
      # print req

      ## Test vector.
      if abs(req.vec.x) > 1 or abs(req.vec.y) > 1:
        echo "invalid move"
        # inform the "cheating" / desynced player
      else:
        gserver.players[msg.conn.id].pos += req.vec

      ## Not fast pasted
      # let res = GResPlayerMoved(playerId: msg.conn.id, pos: gserver.players[msg.conn.id].pos, moveId: req.moveId)
      # let fres = toFlatty(res)
      # for id, player in gserver.players:
      #   # if id != msg.conn.id:
      #   gserver.server.send(player.connection, toFlatty(GMsg(kind: KindGReqPlayerMoved, data: fres)))

    else:
      print "UNKNOWN"

    # echo "GOT MESSAGE: ", msg.data
    # echo message back to the client
    # server.send(msg.conn, "you said:" & msg.data)
    # server.send(msg.conn, "ok")
    if msg.data == "bye":
      gserver.server.disconnect(msg.conn)
    # server.disconnect(msg.conn)
  # Send position updates regardless of previous move TODO good?
  # print "fanout"
  for id, player in gserver.players:
    let res = GResPlayerMoved(playerId: id, pos: player.pos, moveId: -10)
    let fres = toFlatty(res)
    let gmsg = GMsg(kind: Kind_PlayerMoved, data: fres)
    gserver.sendToAllClients(gmsg)


proc mainLoop(gserver: GServer) =
  let tar = calculateFrameTime(gserver.targetServerFps)
  var delta = 0.1
  while true:
    let startt = getMonoTime()
    gserver.main(delta)
    print "tick"
    let endt = getMonoTime()
    let took = (endt - startt).inMilliseconds
    # delta = took
    let sleepTime = (tar - took).clamp(0, 50_000)
    # print(took, sleeptime, took + sleepTime)
    sleep(sleepTime.int)


gserver.configure()
gserver.mainLoop()