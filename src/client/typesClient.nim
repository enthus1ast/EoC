import math
import nimraylib_now
import ../shared
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
import typesAssetLoader
import ecs
import typesSystemPhysic
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

type
  Player* = ref object of Component # is player == crit (critter)?
    id*: Id
    oldpos*: Vector2 # we tween from oldpos
    pos*: Vector2    # to newpos in a "server tick time step"
    lastmove*: MonoTime #
    shape*: chipmunk7.Shape # the players main collision shape


  GClient* = ref object
    nclient*: Reactor
    clientState*: ClientState
    c2s*: Connection
    # players*: Table[Id, Vector2]
    players*: Table[Id, Player]
    myPlayerId*: Id
    connected*: bool

    # Main Menu
    txtServer*: cstring
    moveId*: int32
    # moves*: Table[int32, GReqPlayerMoved]
    moves*: Table[int32, Vector2]

    targetServerFps*: uint8

    serverMessages*: Chatbox

    camera*: Camera2D

    assets*: AssetLoader

    reg*: Registry

    ## Ideally the systems have their own datatype
    ## So that they can store their stuff und not clutter the GClient type
    physic*: SystemPhysic

    # circle*: PhysicsBody # TODO test
    # bodies*: seq[PhysicsBody]

proc finalizePlayer(player: Player) =
  print "finalize player: ", player

# proc newPlayer*(gclient: GClient, playerId: Id, pos: Vector2): Player =
proc newPlayer*(playerId: Id, pos: Vector2): Player =
  new(result, finalizePlayer)
  result.id = playerId
  result.pos = pos
  result.oldpos = pos # on create set both equal
  result.lastmove = getMonoTime()
  # result.shape =