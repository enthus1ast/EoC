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

import ../shared/cPlayer
export cPlayer

type
  # CompPlayer* = ref object of Component # is player == crit (critter)?
  #   id*: Id
  #   oldpos*: Vector2 # we tween from oldpos
  #   pos*: Vector2    # to newpos in a "server tick time step"
  #   lastmove*: MonoTime #
  #   body*: chipmunk7.Body
  #   shape*: chipmunk7.Shape # the players main collision shape
  #   dummyBody*: chipmunk7.Body
  #   dummyJoint*: chipmunk7.Constraint
  #   angularJoint*: chipmunk7.Constraint
  #   controlBody*: chipmunk7.Body
  #   controlJoint*: chipmunk7.Constraint

  CompName* = ref object of Component
    name*: string

  ## Some future components
  CompHealth* = ref object of Component
    health*: int
    maxHealth*: int

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





  # CompMap* = ref object of Component
  #   tiled*: TiledMap

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
    camera*: Camera2D
    assets*: AssetLoader
    reg*: Registry

    ## Ideally the systems have their own datatype
    ## So that they can store their stuff und not clutter the GClient type
    physic*: SystemPhysic
    currentMap*: Entity


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

proc newPlayer*(gclient: GClient, playerId: Id, pos: Vector2, name: string): Entity =
  ## Creates a new player entity
  result = gclient.reg.newEntity()
  var compPlayer: CompPlayer # = new(CompPlayer)
  compPlayer = CompPlayer()
  compPlayer.id = playerId # the network id from netty
  compPlayer.pos = pos
  compPlayer.oldpos = pos # on create set both equal
  compPlayer.lastmove = getMonoTime()
  let radius = 5.0 # TODO these must be configured globally
  let mass = 1.0 # TODO these must be configured globally
  compPlayer.body = addBody(gclient.physic.space, newBody(mass, float.high))
  compPlayer.body.position = v(pos.x, pos.y)
  compPlayer.shape = addShape(gclient.physic.space, newCircleShape(compPlayer.body, radius, vzero))
  compPlayer.shape.friction = 0.1 # TODO these must be configured globally

  ## We create a "control" body, this body we move around
  ## on keypresses
  compPlayer.controlBody = newKinematicBody()

  ## Linear joint
  compPlayer.controlJoint = addConstraint(gclient.physic.space,
    newPivotJoint(compPlayer.controlBody, compPlayer.body, vzero, vzero)
  )
  compPlayer.controlJoint.maxBias = 0 # disable joint correction
  compPlayer.controlJoint.errorBias = 0 # attempt to fully correct the joint each step
  compPlayer.controlJoint.maxForce = 1000.0 # emulate linear friction

  ## Angular joint (player bodies never rotate)
  # cpConstraint *gear = cpSpaceAddConstraint(space, cpGearJointNew(tankControlBody, tankBody, 0.0f, 1.0f));
  # cpConstraintSetErrorBias(gear, 0); // attempt to fully correct the joint each step
  # cpConstraintSetMaxBias(gear, 1.2f);  // but limit it's angular correction rate
  # cpConstraintSetMaxForce(gear, 50000.0f); // emulate angular friction
  compPlayer.angularJoint = addConstraint(gclient.physic.space,
    newGearJoint(compPlayer.controlBody, compPlayer.body, 0.0, 1.0)
  )
  # compPlayer.angularJoint.maxBias = float.high
  # compPlayer.angularJoint.errorBias = 0
  # compPlayer.angularJoint.maxForce = float.high
  compPlayer.angularJoint.maxBias = 2147483647 # TODO is this correct?
  compPlayer.angularJoint.errorBias = 0
  compPlayer.angularJoint.maxForce = 2147483647 # TODO is this correct?

  gclient.reg.addComponent(result, compPlayer)
  gclient.reg.addComponent(result, CompName(name: name))

  ## Register destructor
  proc compPlayerDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    gprint "in implicit internal destructor: " #, CompPlayer(comp)
    var compPlayer = CompPlayer(comp) #gclient.reg.getComponent(entity, CompPlayer)
    gclient.physic.space.removeShape(compPlayer.shape)
    gclient.physic.space.removeBody(compPlayer.body)
    gclient.physic.space.removeConstraint(compPlayer.controlJoint)
    gclient.players.del(compPlayer.id.Id) # TODO check if the same
  gclient.reg.addComponentDestructor(CompPlayer, compPlayerDestructor)








# iterator tileIds*(map: TiledMap): int =
#   ## yields all the tile ids in a TiledMap

# proc newTile*(gclient: GClient, imgKey: string): Entity =
#   ## Creates a new tile entity
#   result = gclient.reg.newEntity()