import ../client/typesClient
import ../server/typesServer
import std/monotimes
import chipmunk7
import ecs
import nimraylib_now
import shared
from cSprite import CompSprite
from cAnimation import CompAnimation

type
  CompVerySimpleDoor* = ref object of Component # is player == crit (critter)?
    open*: bool
    tilePos*: Vector2
    body*: chipmunk7.Body # TODO maybe use CompTilemapObject?
    shape*: chipmunk7.Shape # TODO maybe use CompTilemapObject?


proc newVerySimpleDoor*(gobj: GClient | GServer, tilePos: Vector2, space: Space): Entity =
  ## Creates a very simple testdoor.
  result = gobj.reg.newEntity()
  var compVerySimpleDoor = CompVerySimpleDoor()
  compVerySimpleDoor.tilePos = tilePos
  compVerySimpleDoor.body = addBody(space, newStaticBody())
  compVerySimpleDoor.body.userdata = cast[pointer](result)
  const tileSize = 32 # TODO
  compVerySimpleDoor.body.position =
    v(tilePos.x * tileSize + (tileSize / 2), tilePos.y * tileSize + (tileSize / 2))
  compVerySimpleDoor.shape = addShape(space, newBoxShape(
    compVerySimpleDoor.body, tileSize, tileSize, radius = 1)
  )
  gobj.reg.addComponent(result, compVerySimpleDoor)

  var compSprite = CompSprite()
  compSprite.enabled = true
  compSprite.img = "doorBlock"
  compSprite.pixelPos = v(tilePos.x * tileSize, tilePos.y * tileSize)
  gobj.reg.addComponent(result, compSprite)

  var compAnimation = CompAnimation()
  compAnimation.enabled = true
  compAnimation.spritesheetKey = "laserDing"
  compAnimation.keyframes = @[
    "laserDing 0.ase",
    "laserDing 1.ase",
    "laserDing 2.ase",
    "laserDing 3.ase",
  ]
  compAnimation.duration = 0.200
  compAnimation.progress = 0
  compAnimation.pixelPos = v(tilePos.x * tileSize, tilePos.y * tileSize)
  gobj.reg.addComponent(result, compAnimation)


  proc compVerySimpleDoorDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    space.removeShape(CompVerySimpleDoor(comp).shape)
    space.removeBody(CompVerySimpleDoor(comp).body)
  gobj.reg.addComponentDestructor(CompVerySimpleDoor, compVerySimpleDoorDestructor)

proc openDoor*(gobj: GClient | GServer, entDoor: Entity, open = true) =
  var compSprite = gobj.reg.getComponent(entDoor, CompSprite)
  compSprite.enabled = not open

  var compVerySimpleDoor = gobj.reg.getComponent(entDoor, CompVerySimpleDoor)
  if open:
    compVerySimpleDoor.shape.filter = SHAPE_FILTER_NONE
  else:
    compVerySimpleDoor.shape.filter = ShapeFilter(group: nil, categories: 4294967295'u32, mask: 4294967295'u32)
