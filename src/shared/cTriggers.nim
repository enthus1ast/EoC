import ../client/typesClient
import ../server/typesServer
import ecs
import chipmunk7
import nimraylib_now
import nim_tiled
import ../shared/cSimpleDoor
import fsm

## When server?
import ../server/publicApi

type

  # OnEnterTriggerCb = proc (gobj: GClient | GServer, entA, entB: Entity) {.gcsafe, closure.}
  OnEnterTriggerCb*[T] = proc (gobj: T, entA, entB: Entity) # {.gcsafe, closure.}
  # OnLeaveTriggerCb = proc (gobj: GClient | GServer, entA, entB: Entity) {.gcsafe, closure.}
  OnLeaveTriggerCb*[T] = proc (gobj: T, entA, entB: Entity) {.gcsafe, closure.}

  CompExit* = ref object of Component
  CompTrigger*[T] = ref object of Component
    onEnter*: OnEnterTriggerCb[T]
    onLeave*: OnLeaveTriggerCb[T]

proc newExit*(gobj: GClient | GServer): Entity =
  ## a trigger to leave the map to the worldmap
  result = gobj.reg.newEntity()
  gobj.reg.addComponent(result, CompExit())

  var compTrigger = CompTrigger[gobj.type]()
  compTrigger.onEnter = proc (gobj: gobj.type, entA, entB: Entity) =
    echo "ON ENTER TRIGGER #############"
    when gobj is GClient:
      echo "CLIENT"
      # gobj.fsm.transition(WORLD_MAP) ## THIS IS ONLY FOR TESTING ON THE CLIENT
    when gobj is GServer:
      echo "SERVER"
      echo "Server must send transition to: entA:", entA
      gobj.movePlayerToWorldmap(entA)
      echo "DONE CALLING"


  gobj.reg.addComponent(result, compTrigger)