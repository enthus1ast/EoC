import typesClient

func myPlayer*(gclient: GClient): var Player =
  gclient.players[gclient.myPlayerId]

proc connect*(gclient: GClient, host: string = "127.0.0.1", port: int = 1999) =
  gclient.clientState = CONNECTING
  gclient.c2s = gclient.nclient.connect(host, port)

proc sendKeepalive*(gclient: GClient) =
    var gmsg = GMsg()
    gmsg.kind = Kind_KEEPALIVE
    gmsg.data = ""
    # echo "send keepalive"
    gclient.nclient.send(gclient.c2s, toFlatty(gmsg))

proc disconnect*(gclient: GClient) =
  ## disconnect from any server, and drop back to main screen
  disconnect(gclient.nclient, gclient.c2s)
  gclient.clientState = MAIN_MENU