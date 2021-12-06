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
  CompPlayer* = ref object of Component # is player == crit (critter)?
    id*: Id
    oldpos*: Vector2 # we tween from oldpos
    pos*: Vector2    # to newpos in a "server tick time step"
    lastmove*: MonoTime #
    shape*: chipmunk7.Shape # the players main collision shape

  CompName* = ref object of Component
    name*: string

  # CompMap* = ref object of Component
  #   tiled*: TiledMap

  GClient* = ref object
    nclient*: Reactor
    clientState*: ClientState
    c2s*: Connection
    # players*: Table[Id, Vector2]
    # players*: Table[Id, CompPlayer]
    players*: Table[Id, Entity]
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

proc finalizePlayer(compPlayer: CompPlayer) =
  ## Destroys the collision shape and body of a player
  print "finalize player: ", compPlayer

proc newPlayer*(gclient: GClient, playerId: Id, pos: Vector2, name: string): Entity =
  ## Creates a new player entity
  result = gclient.reg.newEntity()
  var compPlayer = CompPlayer()
  new(compPlayer, finalizePlayer)
  compPlayer.id = playerId # the network id from netty
  compPlayer.pos = pos
  compPlayer.oldpos = pos # on create set both equal
  compPlayer.lastmove = getMonoTime()
  gclient.reg.addComponent(result, compPlayer)
  gclient.reg.addComponent(result, CompName(name: name))

proc newTilemap*(gclient: GClient, mapPath: string): Entity =
  ## Creates a new tilemap entity,
  ## if the map data was not loaded previously, it gets loaded.
  result = gclient.reg.newEntity()

proc newTile*(gclient: GClient, imgKey: string): Entity =
  result = gclient.reg.newEntity()