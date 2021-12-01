import nimraylib_now/mangled/raylib # Vector2


# const
#   PLAYER_CONNECTED* = 0
#   PLAYER_DISCONNECTED* = 1
#   PLAYER_MOVED* = 2

type
  ClientState* = enum
    MAIN_MENU
    CONNECTING
    MAP

  GMsgKind* = enum
    UNKNOWN = 0'u16
    KEEPALIVE
    PLAYER_CONNECTED
    PLAYER_DISCONNECTED
    PLAYER_MOVED
    YOUR_ID_IS

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

