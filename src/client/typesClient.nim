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


  CompTilemap* = ref object of Component
    tiles*: Table[Vector2, Entity]
    objects*: seq[Entity] # TODO better change to table? (with object id as key?)
    tileCollisionBodies*: Table[int, chipmunk7.Body] # TODO remove
    tileCollisionShapes*: Table[int, seq[chipmunk7.Shape]] # TODO remove one tile can have multiple shapes
    mapBoundaryBody*: chipmunk7.Body
    mapBoundarieShapes*: array[4, chipmunk7.Shape]
    objCollisionBodies*: Table[int, chipmunk7.Body] # TODO remove
    objCollisionShapes*: Table[int, chipmunk7.Shape] # TODO remove

  CompTile* = ref object of Component
    xtile*, ytile*: int

  CompTileCollision* = ref object of Component
    body*: chipmunk7.Body
    shapes*: seq[chipmunk7.Shape]

  CompTilemapObject* = ref object of Component
    body*: chipmunk7.Body
    shape*: chipmunk7.Shape


  # CompMap* = ref object of Component
  #   tiled*: TiledMap

  GClient* = ref object
    nclient*: Reactor
    clientState*: ClientState
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

converter toChipmunksVector*(vec: Vector2): Vect {.inline.} =
  result.x = vec.x
  result.y = vec.y

converter toRaylibVector*(vec: Vect): Vector2 {.inline.} =
  result.x = vec.x
  result.y = vec.y

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
  proc compPlayerDestructor(reg: Registry, entity: Entity, comp: Component) {.closure.} =
    print "in implicit internal destructor: " #, CompPlayer(comp)
    var compPlayer = CompPlayer(comp) #gclient.reg.getComponent(entity, CompPlayer)
    gclient.physic.space.removeShape(compPlayer.shape)
    gclient.physic.space.removeBody(compPlayer.body)
    gclient.physic.space.removeConstraint(compPlayer.controlJoint)
    gclient.players.del(compPlayer.id) # TODO check if the same
  gclient.reg.addComponentDestructor(CompPlayer, compPlayerDestructor)


proc newMap*(gclient: GClient, mapKey: string): Entity =
  ## Creates a new tilemap entity,
  echo "Loading map"
  result = gclient.reg.newEntity()
  let map = gclient.assets.maps[mapKey]
  var compTilemap = CompTilemap()

  ## Generate the map collision boundaries
  let widthPixel = (map.width * map.tilewidth).float
  let heightPixel = (map.height * map.tileheight).float
  compTilemap.mapBoundaryBody = addBody(gclient.physic.space, newStaticBody())
  for (idx, line) in enumerate gen4Lines[Vect](x = 0.0, y = 0.0, width = widthPixel, height = heightPixel):
    compTilemap.mapBoundarieShapes[idx] = gclient.physic.space.addShape(
      newSegmentShape(compTilemap.mapBoundaryBody, line.aa, line.bb, 2)
    )

  ## TODO this is mostly copied from the systemDraw, deduplicate code
  let tileset = map.tilesets()[0]
  let texture = gclient.assets.textures[tileset.imagePath()]
  for layer in map.layers:
    for xx in 0..<layer.height:
      for yy in 0..<layer.width:
        let entTile = gclient.reg.newEntity()
        compTilemap.tiles[Vector2(x: xx.float, y: yy.float)] = entTile
        var compTile = CompTile(xtile: xx, ytile: yy)
        gclient.reg.addComponent(entTile, compTile)
        let index = xx + yy * layer.width
        let gid = layer.tiles[index]
        if gid != 0:
          let region = tileset.regions[gid - 1]
          # let sourceReg = Rectangle(x: region.x.float, y: region.y.float, width: region.width.float, height: region.height.float)
          let destPos = Vector2(x: (xx * map.tilewidth).float, y: (yy * map.tileheight).float)
          # drawTextureRec(texture, sourceReg, destPos, White)
          ## Tile Collision shapes
          if tileset.tiles.hasKey(gid - 1): # ids are are not correct in tiled tmx
            var compTileCollision = CompTileCollision()
            let collisionShapes = tileset.tiles[gid - 1].collisionShapes
            print "Created static static body at:", destPos.x, destPos.y
            compTileCollision.body = addBody(gclient.physic.space, newStaticBody())
            compTileCollision.body.position = v(destPos.x + (map.tilewidth / 2), destPos.y + (map.tileheight / 2))
            compTilemap.tileCollisionBodies[index] = compTileCollision.body # TODO remove this? #addBody(gclient.physic.space, newStaticBody())
            compTilemap.tileCollisionBodies[index].position = compTileCollision.body.position # TODO remove this? # v(destPos.x + (map.tilewidth / 2), destPos.y + (map.tileheight / 2))
            # TODO decide if all tile informations should be stored in the tilemap
            # or as an entiy.
            for collisionShape in collisionShapes:
              if collisionShape of TiledTileCollisionShapesRect:
                let rect = TiledTileCollisionShapesRect(collisionShape)
                print "Created TiledTileCollisionShapesRect shape at:", destPos.x, destPos.y, rect.width, rect.height
                if not compTilemap.tileCollisionShapes.hasKey(index): # TODO remove
                  compTilemap.tileCollisionShapes[index] = @[] # TODO remove
                var shape = addShape(gclient.physic.space, newBoxShape(compTilemap.tileCollisionBodies[index], rect.width, rect.height, radius = 1))
                shape.friction = 0
                compTileCollision.shapes.add shape
                compTilemap.tileCollisionShapes[index].add shape # TODO remove

                # ## Test trigger
                # if gid == 215 or gid == 214 or gid == 155:
                #   # Blumentopf
                #   compTilemap.tileCollisionShapes[index][0].sensor = true

                # compTilemap.body = addBody(gclient.physic.space, newBody(mass, float.high))
                # compTilemap.shape = addShape(gclient.physic.space, newCircleShape(compTilemap.body, radius, vzero))
              elif collisionShape of TiledTileCollisionShapesPolygon:
                print "Created TiledTileCollisionShapesPolygon shape at:", destPos.x, destPos.y
                if not compTilemap.tileCollisionShapes.hasKey(index): # TODO remove
                  compTilemap.tileCollisionShapes[index] = @[] # TODO remove
                let poly = TiledTileCollisionShapesPolygon(collisionShape)

                # TODO the polygon tile position is (still) not correct
                # var vecs = poly.points.toVecsChipmunks(Vector2(x: destPos.x - (map.tilewidth.float * 1.5), y: destPos.y - (map.tileheight.float * 1.5) ))
                var vecs = poly.points.toVecsChipmunks(Vector2(x: destPos.x - (map.tilewidth.float / 2) , y: destPos.y - (map.tileheight / 2)  ))
                var shape = addShape(gclient.physic.space,
                  # newBoxShape(compTilemap.tileCollisionBodies[index], rect.width, rect.height, radius = 1)
                  newPolyShape(compTilemap.tileCollisionBodies[index], poly.points.len , addr vecs[0], 1)
                )
                shape.friction = 0
                compTileCollision.shapes.add shape
                compTilemap.tileCollisionShapes[index].add shape # TODO remove
                # compTilemap.tileCollisionShapes[index] = addShape(gclient.physic.space,
                #   newPolyShape(compTilemap.objCollisionBodies[obj.id], poly.points.len , addr vecs[0], 1)
                # )

              else:
                echo "Collision shape not Supported: ", collisionShape.type

              gclient.reg.addComponent(entTile, compTileCollision)


  echo "Creating layer shpaes"
  for objectGroup in map.objectGroups:
    print "create objects for object group:", objectGroup.name
    for obj in objectGroup.objects:
      let entTilemapObj = gclient.reg.newEntity()
      compTilemap.objects.add entTilemapObj
      var compTilemapObject = CompTilemapObject()
      if obj of TiledPolygon:
        # TODO convex shapes does not work yet.
        # print TiledPolygon(obj)
        echo "Create Poly shape"
        var poly = TiledPolygon(obj)
        compTilemapObject.body = addBody(gclient.physic.space, newStaticBody())
        compTilemapObject.body.position = v(obj.x, obj.y)
        compTilemap.objCollisionBodies[obj.id] = compTilemapObject.body # TODO Remove
        # compTilemap.objCollisionBodies[obj.id].position = v(obj.x, obj.y) # TODO Remove
        # var vecs = poly.points.toVecsChipmunks((obj.x, obj.y))
        var vecs = poly.points.toVecsChipmunks((0.0, 0.0))
        compTilemapObject.shape = addShape(gclient.physic.space,
          newPolyShape(compTilemapObject.body, poly.points.len , addr vecs[0], 1)
        )
        compTilemap.objCollisionShapes[obj.id] = compTilemapObject.shape # TODO Remove
      else:
        # Rectangle
        print obj.id
        compTilemapObject.body = addBody(gclient.physic.space, newStaticBody())
        compTilemapObject.body.position = v(obj.x + (obj.width / 2), obj.y + (obj.height / 2))
        compTilemap.objCollisionBodies[obj.id] = compTilemapObject.body # TODO Remove
        compTilemapObject.shape = addShape(gclient.physic.space,
          newBoxShape(compTilemapObject.body, obj.width, obj.height, radius = 1)
        )
        compTilemap.objCollisionShapes[obj.id] = compTilemapObject.shape # TODO Remove
      # TODO create collisions from the rest of the obj shapes

      gclient.reg.addComponent(entTilemapObj, compTilemapObject)


  echo "done"

  ## Register destructor
  proc compTilemapDestructor(reg: Registry, entity: Entity, comp: Component) {.closure.} =
    print "in implicit internal tilemap destructor: "
    var compTilemap = CompTilemap(comp)

    ## Invalidate all the tiles, they will get freed later
    for entTile in compTilemap.tiles.values:
      gclient.reg.invalidateEntity(entTile)

    for entTile in compTilemap.tiles.values:
      gclient.reg.invalidateEntity(entTile)

  # Register in the ecs
  gclient.reg.addComponentDestructor(CompTilemap, compTilemapDestructor)

  proc compTileCollisionDestructor(reg: Registry, entity: Entity, comp: Component) {.closure.} =
    print "in implicit internal CompTileCollision destructor: "
    for shape in CompTileCollision(comp).shapes:
      gclient.physic.space.removeShape(shape)
    gclient.physic.space.removeBody(CompTileCollision(comp).body)
  gclient.reg.addComponentDestructor(CompTileCollision, compTileCollisionDestructor)

  proc compCompTilemapObjectDestructor(reg: Registry, entity: Entity, comp: Component) {.closure.} =
    print "in implicit internal CompTilemapObject destructor: "
    gclient.physic.space.removeShape(CompTilemapObject(comp).shape)
    gclient.physic.space.removeBody(CompTilemapObject(comp).body)
  gclient.reg.addComponentDestructor(CompTilemapObject, compCompTilemapObjectDestructor)





# iterator tileIds*(map: TiledMap): int =
#   ## yields all the tile ids in a TiledMap

# proc newTile*(gclient: GClient, imgKey: string): Entity =
#   ## Creates a new tile entity
#   result = gclient.reg.newEntity()