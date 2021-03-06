import typesClient

# func myPlayer*(gclient: GClient): Option[Entity] =
#   try:
#     some gclient.players[gclient.myPlayerId]
#   except:
#     return

func myPlayer*(gclient: GClient): Entity =
  try:
    gclient.players[gclient.myPlayerId]
  except:
    raise newException(ValueError, "myPlayerId is invalid")

proc connect*(gclient: GClient, host: string = "127.0.0.1", port: int = 1999) =
  gclient.fsm.transition(CONNECTING)
  try:
    gclient.c2s = gclient.nclient.connect(host, port)
  except:
    echo getCurrentExceptionMsg()
    gclient.serverMessages.add("could not connect to server! " & host & " " & $port)
    #gclient.fsm.transition(MAIN_MENU)


proc sendKeepalive*(gclient: GClient) =
  ## Sends a keepalive to the server
  var gmsg = GMsg()
  gmsg.kind = Kind_KEEPALIVE
  gmsg.data = toFlatty(monotimes.getMonoTime())
  # echo "send keepalive"
  gclient.nclient.send(gclient.c2s, toFlatty(gmsg))

proc disconnect*(gclient: GClient) =
  ## disconnect from any server, and drop back to main screen
  echo "Call disconnect"
  try:
    disconnect(gclient.nclient, gclient.c2s)
  except:
    echo getCurrentExceptionMsg()
    # gclient.serverMessages.add("could not connect to server! (disconnect)")
  echo "Call disconnect done"
  # gclient.fsm.transition(MAIN_MENU)