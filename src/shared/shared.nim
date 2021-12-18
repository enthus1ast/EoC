import nimraylib_now/mangled/raylib # Vector2
# import nimraylib_now/mangled/raymath

from chipmunk7 import Vect

import print
export print

# const
#   PLAYER_CONNECTED* = 0
#   PLAYER_DISCONNECTED* = 1
#   KindGReqPlayerMoved* = 2

converter toChipmunksVector*(vec: Vector2): Vect {.inline.} =
  result.x = vec.x
  result.y = vec.y

converter toRaylibVector*(vec: Vect): Vector2 {.inline.} =
  result.x = vec.x
  result.y = vec.y


type
  ClientState* = enum
    MAIN_MENU
    CONNECTING
    MAP
    WORLD_MAP

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
    moveVector*: Vect
    velocity*: Vect
    controlBodyPos*: Vect
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
    serverVersion*: uint16 # client must match

func calculateFrameTime*(targetFps: int | uint8): int =
  ## calculates the time a frame must take
  ## when on `targetFps`
  return (1000 / targetFps.int).int

template gprint*(body: varargs[untyped]) =
  {.cast(gcsafe).}:
    print body