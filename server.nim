import netty
import print
import os
import shared
import flatty
import tables
import nimraylib_now/mangled/raylib # Vector2
import nimraylib_now/mangled/raymath # Vector2
import std/monotimes
import std/times

const TARGET_FPS = 5

type
  Player = object
    id: Id
    connection: Connection
    pos: Vector2
  GServer = ref object
    players: Table[Id, Player]
    server: Reactor

var gserver = GServer()
gserver.players = initTable[Id, Player]()
gserver.server = newReactor("127.0.0.1", 1999)

echo "Listenting for UDP on 127.0.0.1:1999"

proc sendToAllClients(gserver: GServer, gmsg: GMsg) =
  let msg = toFlatty(gmsg)
  for id, player in gserver.players:
    gserver.server.send(player.connection, msg)

# main loop

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
    player.pos = Vector2(x: 10, y: 10) # TODO
    gserver.players[connection.id] = player

    # send the new connecting player his id
    let fgResYourIdIs = toFlatty(GResYourIdIs(playerId: connection.id))
    gserver.server.send(connection, toFlatty(GMsg(kind: YOUR_ID_IS, data: fgResYourIdIs)))

    # update the new connected player about all the other players
    # TODO this should not be a move but a GResPlayerConnected
    # let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    # server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))
    for id, player in gserver.players:
      if id != connection.id:
        let res = GResPlayerConnected(playerId: id, pos: player.pos)
        let fres = toFlatty(res)
        gserver.server.send(connection, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fres)))


    # tell every other player about the new connected player
    let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    for player in gserver.server.connections:
      # server.send(player, "Player connected:" & $connection.id)
      gserver.server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))


  for connection in gserver.server.deadConnections:
    echo "[dead] ", connection.address
    gserver.players.del(connection.id)
    # for player in server.connections:
    for id, player in gserver.players:
      # server.send(player, "Player leaves:" & $player.id)
      let fgResPlayerDisconnects = toFlatty(GResPlayerDisconnects(playerId: id))
      gserver.server.send(player.connection, toFlatty(GMsg(kind: PLAYER_DISCONNECTED, data: fgResPlayerDisconnects)))



  for msg in gserver.server.messages:

    # Try to unpack
    var gmsg = fromFlatty(msg.data, GMsg)
    case gmsg.kind
    of KEEPALIVE:
      discard
    of PLAYER_CONNECTED:
      print PLAYER_CONNECTED
    of PLAYER_DISCONNECTED:
      print PLAYER_DISCONNECTED
    of PLAYER_MOVED:
      # print PLAYER_MOVED
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
      #   gserver.server.send(player.connection, toFlatty(GMsg(kind: PLAYER_MOVED, data: fres)))

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
  print "fanout"
  for id, player in gserver.players:
    let res = GResPlayerMoved(playerId: id, pos: player.pos, moveId: -10)
    let fres = toFlatty(res)
    let gmsg = GMsg(kind: PLAYER_MOVED, data: fres)
    gserver.sendToAllClients(gmsg)


proc mainLoop(gserver: GServer) =
  let tar = (1000 / TARGET_FPS).int
  while true:
    let startt = getMonoTime()
    let delta = 0.1 # todo
    gserver.main(delta)
    let endt = getMonoTime()
    let took = (endt - startt).inMilliseconds
    let sleepTime = (tar - took).clamp(0, 50_000)
    print(took, sleeptime, took + sleepTime)
    sleep(sleepTime.int)

gserver.mainLoop()