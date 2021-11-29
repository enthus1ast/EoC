import netty, os

# create connection
var client = newReactor()
# connect to server
var c2s = client.connect("127.0.0.1", 1999)
# send message on the connection
# main loop
var idx = 0
var connected = true
while connected:
  sleep(250)
  idx.inc
  echo "."
  client.tick()
  if idx mod 10 == 0:
    echo "send"
    client.send(c2s, "hi")
  # if idx == 200:

  if idx == 200:
    echo "disco"
    client.send(c2s, "bye")
    # client.disconnect(c2s)
    # break
  # must call tick to both read and write
  # usually there are no new messages, but if there are
  # c2s.close()
  for msg in client.messages:
    # print message data
    echo "GOT MESSAGE: ", msg.data
  for connection in client.newConnections:
    echo "[new] ", connection.address
  for connection in client.deadConnections:
    echo "[dead] ", connection.address
    connected = false