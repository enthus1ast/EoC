import math
import nimraylib_now
import ../shared/shared
import json
import tables
import print
import strformat
import std/monotimes
import std/times
import std/enumerate
import asyncdispatch
import chatbox
import netty, os, flatty
import ../shared/typesAssetLoader
import ecs
import typesSystemPhysic
import typesSystemDraw
import nim_tiled
import fsm
import options
# import

export math
# export nimraylib_now
export shared
export json
export tables
export print
export strformat
export monotimes
export times
export enumerate
export asyncdispatch
export chatbox
export netty, os, flatty
export typesAssetLoader
export ecs
export fsm
export options


type
  CompName* = ref object of Component
    name*: string

  ## Some future components
  CompRadiation* = ref object of Component
    radiation*: int ## Radiation reduces the CompHealth.maxHealth permanently (until cured)

  CompPoison* = ref object of Component
    poisonAmount*: int ## how many "posion" you have
    poisonStrength*: int ## how strong this poison is

  CompSpecial* = ref object of Component
    strength*: int ## which modifies Hit Points, melee damage, and Carry Weight.
    perception*: int ## which modifies Sight, Sequence, and ranged combat distance modifiers.
    endurance*: int ## which modifies Hit Points, Poison and Rad Resistance, Healing Rate and additional Hit Points per level.
    charisma*: int ## which modifies Party Points, NPC reactions, and more.
    intelligence*: int ## which modifies additional Skill points per level, dialogue options, and many Skills.
    agility*: int ## which modifies Action Points, Armor Class, and some Skills.
    luck*: int ## which modifies critical Bypass, weapon failures, and certain unseen factors as you play.

  CompLevel* = ref object of Component
    level*: int
    xp*: int

  GClient* = ref object
    nclient*: Reactor
    fsm*: Fsm[ClientState]
    c2s*: Connection
    players*: Table[Id, Entity]
    myPlayerId*: Id
    connected*: bool
    debugDraw*: bool

    # Main Menu
    txtServer*: cstring # TODO find a better alternative to cstring!
    moveId*: int32
    # moves*: Table[int32, GReqPlayerMoved]
    moves*: Table[int32, Vector2]
    targetServerFps*: uint8
    serverMessages*: Chatbox
    assets*: AssetLoader
    reg*: Registry

    ## Ideally the systems have their own datatype
    ## So that they can store their stuff und not clutter the GClient type
    physic*: SystemPhysic
    draw*: SystemDraw
    currentMap*: Entity
    # maps*: Table[WorldmapPos, Entity]


## TODO these could be generic
proc toVecs*(points: seq[(float, float)], pos: Vector2): seq[Vector2] {.inline.} =
  result = @[]
  for point in points:
    result.add Vector2(x: point[0] + pos.x, y: point[1] + pos.y)

proc toVecsChipmunks*(points: seq[(float, float)], pos: Vector2): seq[Vect] {.inline.} =
  result = @[]
  for point in points:
    result.add Vect(x: point[0] + pos.x, y: point[1] + pos.y)


iterator gen4Lines*[T](x, y, width, height: float): tuple[aa: T, bb: T] {.inline.} =
  ## this generates 4 lines forming a rectangle
  ## generates them clockwise
  ## aa := start ; bb := end  of a line
  yield (aa: T(x: x, y: y),                  bb: T(x: x + width, y: y))
  yield (aa: T(x: x + width, y: y),          bb: T(x: x + width, y: y + height))
  yield (aa: T(x: x + width, y: y + height), bb: T(x: x, y: y + height))
  yield (aa: T(x: x, y: y + height),         bb: T(x: x, y: y))


# iterator tileIds*(map: TiledMap): int =
#   ## yields all the tile ids in a TiledMap

# proc newTile*(gclient: GClient, imgKey: string): Entity =
#   ## Creates a new tile entity
#   result = gclient.reg.newEntity()