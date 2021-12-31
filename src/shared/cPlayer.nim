import ../client/typesClient
import ../server/typesServer
import std/monotimes
import chipmunk7
import ecs
import nimraylib_now
import shared
import cTriggers
import cHealth

type
  CompPlayer* = ref object of Component # is player == crit (critter)?
    id*: Id
    oldpos*: Vector2 # we tween from oldpos
    pos*: Vector2    # to newpos in a "server tick time step"
    lastmove*: MonoTime #
    body*: chipmunk7.Body
    shape*: chipmunk7.Shape # the players main collision shape
    dummyBody*: chipmunk7.Body
    dummyJoint*: chipmunk7.Constraint
    angularJoint*: chipmunk7.Constraint
    controlBody*: chipmunk7.Body
    controlJoint*: chipmunk7.Constraint
    desiredPosition*: chipmunk7.Vect

proc newPlayer*(gclient: GClient, playerId: Id, pos: Vector2, name: string, hasCollision: bool = true): Entity =
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
  compPlayer.body.userdata = cast[pointer](result)
  compPlayer.body.position = v(pos.x, pos.y)
  if hasCollision:
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

  var compHealth = CompHealth()
  compHealth.maxHealth = 150
  compHealth.health = 100
  gclient.reg.addComponent(result, compHealth)


  ## Register player collision callback
  proc playerCallback(a: Arbiter; space: Space; data: pointer): bool {.cdecl.} =
    ## Collision callback definition
    print "COLLISION" #, pgclient
    if space.userdata.isNil:
      print  space.userdata.isNil
    else:
      print space.userdata
      var gclient = cast[ref GClient](space.userdata) # TODO this must be either GClient or GServer!
      var bodyA: chipmunk7.Body
      var bodyB: chipmunk7.Body
      a.bodies(addr bodyA, addr bodyB)
      print bodyA.userdata, bodyB.userdata

      var entA = cast[Entity](bodyA.userdata)
      var entB = cast[Entity](bodyB.userdata)

      if gclient.reg.hasComponent(entB, CompTrigger[GClient]):
        var compTrigger = gclient.reg.getComponent(entB, CompTrigger[GClient])
        echo "TRIGGER" # TODO this should call the associated trigger script/building function?
        if not compTrigger.onEnter.isNil:
          ####
          #### TODO the client should not trigger anything game relevant,
          #### but must wait on the server to tell him so
          ####
          # gclient.fsm.transition(WORLD_MAP) # TODO replace this with correct code (call CB)
          compTrigger.onEnter(gclient, entA, entB)
          # if false:
          # discard
          # else:
        return false # trigger has no collision

    # else:
    result = true
  # var handler = space.addCollisionHandler(ctBorder, ctBlueBall)
  var handler = gclient.physic.space.addCollisionHandler(cast[CollisionType](0), cast[CollisionType](0))
  # handler.postSolveFunc = cast[CollisionpostSolveFunc](playerCallback)
  handler.beginFunc = cast[CollisionBeginFunc](playerCallback)


  ## Register destructor
  proc compPlayerDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    gprint "in implicit internal destructor: " #, CompPlayer(comp)
    var compPlayer = CompPlayer(comp) #gclient.reg.getComponent(entity, CompPlayer)
    gclient.physic.space.removeShape(compPlayer.shape)
    gclient.physic.space.removeBody(compPlayer.body)
    gclient.physic.space.removeConstraint(compPlayer.controlJoint)
    gclient.players.del(compPlayer.id.Id) # TODO check if the same
  gclient.reg.addComponentDestructor(CompPlayer, compPlayerDestructor)