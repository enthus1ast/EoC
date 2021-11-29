import netty
import print
import os
import shared
import flatty
import tables
import nimraylib_now/mangled/raylib # Vector2

var players = initTable[Id, Connection]()


# listen for a connection on localhost port 1999
var server = newReactor("127.0.0.1", 1999)
echo "Listenting for UDP on 127.0.0.1:1999"
# main loop
while true:
  # sleep(250)
  sleep(10)
  # must call tick to both read and write
  # usually there are no new messages, but if there are
  # echo "tick"
  server.tick()
  for connection in server.newConnections:
    echo "[new] ", connection.address
    players[connection.id] = connection
    let fgResYourIdIs = toFlatty(GResYourIdIs(playerId: connection.id))
    server.send(connection, toFlatty(GMsg(kind: YOUR_ID_IS, data: fgResYourIdIs)))

    let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    for player in server.connections:
      # server.send(player, "Player connected:" & $connection.id)
      server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))
  for connection in server.deadConnections:
    echo "[dead] ", connection.address
    players.del(connection.id)
    # for player in server.connections:
    for id, connection in players:
      # server.send(player, "Player leaves:" & $connection.id)
      let fgResPlayerDisconnects = toFlatty(GResPlayerDisconnects(playerId: connection.id))
      server.send(connection, toFlatty(GMsg(kind: PLAYER_DISCONNECTED, data: fgResPlayerDisconnects)))


  for msg in server.messages:
    # print message data
    # print msg.data

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
      var pos = fromFlatty(gmsg.data, Vector2)
      # print pos
      let res = GResPlayerMoved(playerId: msg.conn.id, pos: pos)
      let fres = toFlatty(res)
      for id, conn in players:
        if id != msg.conn.id:
          server.send(conn, toFlatty(GMsg(kind: PLAYER_MOVED, data: fres)))
    else:
      print "UNKNOWN"

    # echo "GOT MESSAGE: ", msg.data
    # echo message back to the client
    # server.send(msg.conn, "you said:" & msg.data)
    # server.send(msg.conn, "ok")
    if msg.data == "bye":
      server.disconnect(msg.conn)
    # server.disconnect(msg.conn)