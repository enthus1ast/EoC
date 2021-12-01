import netty
import print
import os
import shared
import flatty
import tables
import nimraylib_now/mangled/raylib # Vector2
import nimraylib_now/mangled/raymath # Vector2


type
  Player = object
    id: Id
    connection: Connection
    pos: Vector2

var players = initTable[Id, Player]()


# proc sendToAllClients(server: Reactor, )


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

    var player = Player()
    player.id = connection.id
    player.connection = connection
    player.pos = Vector2(x: 10, y: 10) # TODO
    players[connection.id] = player

    # send the new connecting player his id
    let fgResYourIdIs = toFlatty(GResYourIdIs(playerId: connection.id))
    server.send(connection, toFlatty(GMsg(kind: YOUR_ID_IS, data: fgResYourIdIs)))

    # update the new connected player about all the other players
    # TODO this should not be a move but a GResPlayerConnected
    # let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    # server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))
    for id, player in players:
      if id != connection.id:
        let res = GResPlayerConnected(playerId: id, pos: player.pos)
        let fres = toFlatty(res)
        server.send(connection, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fres)))


    # tell every other player about the new connected player
    let fgResPlayerConnected = toFlatty(GResPlayerConnected(playerId: connection.id))
    for player in server.connections:
      # server.send(player, "Player connected:" & $connection.id)
      server.send(player, toFlatty(GMsg(kind: PLAYER_CONNECTED, data: fgResPlayerConnected)))


  for connection in server.deadConnections:
    echo "[dead] ", connection.address
    players.del(connection.id)
    # for player in server.connections:
    for id, player in players:
      # server.send(player, "Player leaves:" & $player.id)
      let fgResPlayerDisconnects = toFlatty(GResPlayerDisconnects(playerId: id))
      server.send(player.connection, toFlatty(GMsg(kind: PLAYER_DISCONNECTED, data: fgResPlayerDisconnects)))


  sleep(100)

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
      var req = fromFlatty(gmsg.data, GReqPlayerMoved)
      print req

      ## Test vector.
      if abs(req.vec.x) > 1 or abs(req.vec.y) > 1:
        echo "invalid move"
        # inform the "cheating" / desynced player
      else:
        players[msg.conn.id].pos += req.vec

      let res = GResPlayerMoved(playerId: msg.conn.id, pos: players[msg.conn.id].pos, moveId: req.moveId)
      let fres = toFlatty(res)
      for id, player in players:
        # if id != msg.conn.id:
        server.send(player.connection, toFlatty(GMsg(kind: PLAYER_MOVED, data: fres)))
    else:
      print "UNKNOWN"

    # Send position updates regardless of previous move TODO good?
    # for id, player in players:
    #   # if id != msg.conn.id:
    #   for id, player in players:
    #   server.send(player.connection, toFlatty(GMsg(kind: PLAYER_MOVED, data: fres)))

    # echo "GOT MESSAGE: ", msg.data
    # echo message back to the client
    # server.send(msg.conn, "you said:" & msg.data)
    # server.send(msg.conn, "ok")
    if msg.data == "bye":
      server.disconnect(msg.conn)
    # server.disconnect(msg.conn)
