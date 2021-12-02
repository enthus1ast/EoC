import nimraylib_now/mangled/raylib # Vector2


# const
#   PLAYER_CONNECTED* = 0
#   PLAYER_DISCONNECTED* = 1
#   KindGReqPlayerMoved* = 2

type
  ClientState* = enum
    MAIN_MENU
    CONNECTING
    MAP

  GMsgKind* = enum
    Kind_UNKNOWN = 0'u16
    Kind_KEEPALIVE
    Kind_PlayerConnected
    Kind_PlayerDisconnects
    Kind_PlayerMoved
    Kind_YourIdIs
    Kind_ServerInfo

  Id* = uint32
  GMsg* = object
    kind*: GMsgKind
    data*: string

  GReqPlayerMoved* = object
    moveId*: int32
    vec*: Vector2
  GResPlayerMoved* = object
    playerId*: Id
    moveId*: int32
    pos*: Vector2

  GReqPlayerConnected* = object
  GResPlayerConnected* = object
    playerId*: Id
    pos*: Vector2
  GResYourIdIs* = object
    playerId*: Id

  GResPlayerDisconnects* = object
    playerId*: Id

  GResServerInfo* = object
    targetServerFps*: uint8

func calculateFrameTime*(targetFps: int | uint8): int =
  ## calculates the time a frame must take
  ## when on `targetFps`
  return (1000 / targetFps.int).int