import ../client/typesClient
import ../server/typesServer
import std/monotimes
import chipmunk7
import ecs
import nimraylib_now
import shared

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
    map*: Entity # the map the player is on
