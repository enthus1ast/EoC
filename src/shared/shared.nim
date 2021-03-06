import nimraylib_now/mangled/raylib # Vector2
import hashes

import ecs
export ecs

import intsets
export intsets



# import nimraylib_now/mangled/raymath

from chipmunk7 import Vect


import print
export print

const
  WORLDMAP_ENTITY* = -1.Entity

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
    Kind_PlayerWorldmap

  Id* = distinct uint32
  GMsg* = object
    kind*: GMsgKind
    compressed*: bool
    data*: string

  GReqPlayerMoved* = object
    moveId*: int32
    bodyPos*: Vector2
    moveVector*: Vect
    velocity*: Vect
    controlBodyPos*: Vect
  GResPlayerMoved* = object
    playerId*: Id
    moveId*: int32
    pos*: Vector2
    velocity*: Vect

  GResPlayerWorldmap* = object
    ## tells all the players that the current player moved to the worldmap
    ## clients should remove the player from the map? Or should the server send an additional disconnect command?
    playerId*: Id

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

  # Events
  EvPlayerMovedToWorldmap* = object
    entPlayer*: Entity
    id*: Id
  EvPlayerDisconnected* = object
    entPlayer*: Entity
    id*: Id
    reason*: string
    pgserver*: pointer

proc hash*(a: Id): Hash {.borrow.}
proc `$`*(a: Id): string {.borrow.}
proc `==`*(a, b: Id): bool {.borrow.}


func calculateFrameTime*(targetFps: int | uint8): int =
  ## calculates the time a frame must take
  ## when on `targetFps`
  return (1000 / targetFps.int).int

template gprint*(body: varargs[untyped]) =
  {.cast(gcsafe).}:
    print body

proc addOverflow*[T](aa: var T , bb: T, maxval: T) {.inline.} =
  if aa + bb > maxval:
    aa = bb - aa
  else:
    aa += bb

when isMainModule:
  var ii = 10
  ii.addOverflow(11, maxval = 20)
  assert ii == 1