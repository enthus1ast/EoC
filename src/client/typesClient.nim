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
    controlBody*: chipmunk7.Body
    controlJoint*: chipmunk7.Constraint


  CompName* = ref object of Component
    name*: string

  CompTilemap* = ref object of Component
    tiles*: Table[Vector2, Entity]
    tileCollisionBodies*: Table[int, chipmunk7.Body]
    tileCollisionShapes*: Table[int, chipmunk7.Shape]
    mapBoundaryBody*: chipmunk7.Body
    mapBoundarieShapes*: array[4, chipmunk7.Shape]
    objCollisionBodies*: Table[int, chipmunk7.Body]
    objCollisionShapes*: Table[int, chipmunk7.Shape]

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
    debugDraw*: bool

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

    currentMap*: Entity

    # circle*: PhysicsBody # TODO test
    # bodies*: seq[PhysicsBody]

# proc finalizePlayer(compPlayer: CompPlayer) =
#   ## Destroys the collision shape and body of a player
#   print "finalize player" #, compPlayer
#   # Must remove the shape and body from the space first!
#   # problem, how to get gclient obj?
#   compPlayer.shape.destroy()
#   compPlayer.body.destroy()

proc finalizePlayer(compPlayer: CompPlayer) =
  ## Destroys the collision shape and body of a player
  print "finalize player" #, compPlayer
  # Must remove the shape and body from the space first!
  # problem, how to get gclient obj?
  # compPlayer.shape.destroy()
  # compPlayer.body.destroy()
  # print gclient

proc destroyPlayer*(gclient: GClient, entity: Entity, playerId: Id) =
  var compPlayer = gclient.reg.getComponent(entity, CompPlayer)
  gclient.physic.space.removeShape(compPlayer.shape)
  gclient.physic.space.removeBody(compPlayer.body)
  gclient.reg.destroyEntity(entity)
  gclient.players.del(playerId)


## TODO this could be generic
proc toVecs*(points: seq[(float, float)], pos: Vector2): seq[Vector2] =
  result = @[]
  for point in points:
    result.add Vector2(x: point[0] + pos.x, y: point[1] + pos.y)

proc toVecsChipmunks*(points: seq[(float, float)], pos: Vector2): seq[Vect] =
  result = @[]
  for point in points:
    result.add Vect(x: point[0] + pos.x, y: point[1] + pos.y)

proc newPlayer*(gclient: GClient, playerId: Id, pos: Vector2, name: string): Entity =
  ## Creates a new player entity
  result = gclient.reg.newEntity()
  var compPlayer: CompPlayer # = new(CompPlayer)
  compPlayer = CompPlayer()
  # new(compPlayer, finalizePlayer)
  compPlayer.id = playerId # the network id from netty
  compPlayer.pos = pos
  compPlayer.oldpos = pos # on create set both equal
  compPlayer.lastmove = getMonoTime()
  let radius = 5.0
  let mass = 1.0
  # let moment = momentForCircle(mass, 0, radius, vzero)
  # let moment = momentForCircle(mass, 0, radius, vzero)
  # compPlayer.body = addBody(gclient.physic.space, newBody(mass, moment))
  compPlayer.body = addBody(gclient.physic.space, newBody(mass, float.high))
  compPlayer.body.position = v(pos.x, pos.y)
  compPlayer.shape = addShape(gclient.physic.space, newCircleShape(compPlayer.body, radius, vzero))
  compPlayer.shape.friction = 0.1

  ## We create a dummy static object
  ## that we use to restrict movements
  ## to emulate linear friction
  # compPlayer.dummyBody = gclient.physic.space.staticBody()
  # compPlayer.dummyJoint = addConstraint(gclient.physic.space,
  #   newPivotJoint(compPlayer.dummyBody, compPlayer.body, vzero, vzero)
  # )
  # compPlayer.dummyJoint.maxBias = 0 # disable joint correction
  # compPlayer.dummyJoint.maxForce = 1000.0 # emulate linear friction

  ## We create a "control" body, this body we move around
  ## on keypresses
  compPlayer.controlBody = newKinematicBody()
  compPlayer.controlJoint = addConstraint(gclient.physic.space,
    newPivotJoint(compPlayer.controlBody, compPlayer.body, vzero, vzero)
  )
  compPlayer.controlJoint.maxBias = 0 # disable joint correction
  compPlayer.controlJoint.errorBias = 0 # attempt to fully correct the joint each step
  compPlayer.controlJoint.maxForce = 1000.0 # emulate linear friction

  gclient.reg.addComponent(result, compPlayer)
  gclient.reg.addComponent(result, CompName(name: name))


proc newMap*(gclient: GClient, mapKey: string): Entity =
  ## Creates a new tilemap entity,
  echo "Loading map"
  result = gclient.reg.newEntity()
  let map = gclient.assets.maps["assets/maps/demoTown.tmx"]
  var compTilemap = CompTilemap()

  ## Generate the map collision boundaries
  let widthPixel = (map.width * map.tilewidth).float
  let heightPixel = (map.height * map.tileheight).float
  compTilemap.mapBoundaryBody = addBody(gclient.physic.space, newStaticBody())
  compTilemap.mapBoundarieShapes[0] = gclient.physic.space.addShape(
    newSegmentShape(compTilemap.mapBoundaryBody, v(0.0, 0.0), v(widthPixel, 0.0), 2)
  )
  compTilemap.mapBoundarieShapes[1] = gclient.physic.space.addShape(
    newSegmentShape(compTilemap.mapBoundaryBody, v(widthPixel, 0.0), v(widthPixel, heightPixel), 2)
  )
  compTilemap.mapBoundarieShapes[2] = gclient.physic.space.addShape(
    newSegmentShape(compTilemap.mapBoundaryBody, v(widthPixel, heightPixel), v(0.0, heightPixel), 2)
  )
  compTilemap.mapBoundarieShapes[3] = gclient.physic.space.addShape(
    newSegmentShape(compTilemap.mapBoundaryBody, v(0.0, heightPixel), v(0.0, 0.0), 2)
  )


  ## Todo this is just copied from the systemDraw
  let tileset = map.tilesets()[0]
  let texture = gclient.assets.textures[tileset.imagePath()]
  for layer in map.layers:
    for xx in 0..<layer.height:
      for yy in 0..<layer.width:
        let index = xx + yy * layer.width
        let gid = layer.tiles[index]
        if gid != 0:
          let region = tileset.regions[gid - 1]
          let sourceReg = Rectangle(x: region.x.float, y: region.y.float, width: region.width.float, height: region.height.float)
          let destPos = Vector2(x: (xx * map.tilewidth).float, y: (yy * map.tileheight).float)
          # drawTextureRec(texture, sourceReg, destPos, White)
          ## Tile Collision shapes
          if tileset.tiles.hasKey(gid - 1): # ids are are not correct in tiled tmx
            let collisionShapes = tileset.tiles[gid - 1].collisionShapes
            print "Created static static body at:", destPos.x, destPos.y
            compTilemap.tileCollisionBodies[index] = addBody(gclient.physic.space, newStaticBody())
            compTilemap.tileCollisionBodies[index].position = v(destPos.x + (map.tilewidth / 2), destPos.y + (map.tileheight / 2))
            for collisionShape in collisionShapes:
              if collisionShape of TiledTileCollisionShapesRect:
                let rect = TiledTileCollisionShapesRect(collisionShape)
                print "Created static shape at:", destPos.x, destPos.y, rect.width, rect.height
                ## TODO this leaks shapes! since we overwrite each shape
                compTilemap.tileCollisionShapes[index] = addShape(gclient.physic.space, newBoxShape(compTilemap.tileCollisionBodies[index], rect.width, rect.height, radius = 1))
                compTilemap.tileCollisionShapes[index].friction = 0

                ## Test trigger
                if gid == 215 or gid == 214 or gid == 155:
                  # Blumentopf
                  compTilemap.tileCollisionShapes[index].sensor = true

                # compTilemap.body = addBody(gclient.physic.space, newBody(mass, float.high))
                # compTilemap.shape = addShape(gclient.physic.space, newCircleShape(compTilemap.body, radius, vzero))
              else:
                echo "Collision shape not Supported: ", collisionShape.type

  echo "Creating layer shpaes"
  for objectGroup in map.objectGroups:
    # nim_tiled cannot show which TiledObject we have
    # but we know that these are polygons
    # void DrawLineStrip(Vector2 *points, int pointsCount, Color color);   // Draw lines sequence
    # print objectGroup

    # let color =
    #   case objectGroup.name
    #   of "Exit": Red
    #   of "Next": Green
    #   else: Black
    for obj in objectGroup.objects:
      if obj of TiledPolygon:
        discard # TODO TiledPolygon
        # print TiledPolygon(obj)
        echo "Create Poly shape"
        var poly = TiledPolygon(obj)
        compTilemap.objCollisionBodies[obj.id] = addBody(gclient.physic.space, newStaticBody())
        compTilemap.objCollisionBodies[obj.id].position = v(obj.x, obj.y)
        # var vecs = poly.points.toVecsChipmunks((obj.x, obj.y))
        var vecs = poly.points.toVecsChipmunks((0.0, 0.0))
        compTilemap.objCollisionShapes[obj.id] = addShape(gclient.physic.space,
          newPolyShape(compTilemap.objCollisionBodies[obj.id], poly.points.len , addr vecs[0], 1)
        )

        # proc newPolyShape*(body: Body; count: cint; verts: ptr Vect; radius: Float): PolyShape {.cdecl, importc: "cpPolyShapeNewRaw".}


      else: # Rectangle
        print obj.id
        compTilemap.objCollisionBodies[obj.id] = addBody(gclient.physic.space, newStaticBody())
        compTilemap.objCollisionBodies[obj.id].position = v(obj.x + (obj.width / 2), obj.y + (obj.height / 2))
        compTilemap.objCollisionShapes[obj.id] = addShape(gclient.physic.space,
          newBoxShape(compTilemap.objCollisionBodies[obj.id], obj.width, obj.height, radius = 1)
        )

      # TODO create collisions from the rest of the obj shapes
    #   # drawLineStrip(addr vecs[0], vecs.len, color)
    #   # var vecs = toVecs(TiledPolygon(obj).points, (obj.x, obj.y))

    #   var vecs = toVecs(TiledPolygon(obj).points, (obj.x, obj.y))
    #   drawLineStrip(addr vecs[0], vecs.len, color)
  echo "done"
# iterator tileIds*(map: TiledMap): int =
#   ## yields all the tile ids in a TiledMap


# proc newTile*(gclient: GClient, imgKey: string): Entity =
#   ## Creates a new tile entity
#   result = gclient.reg.newEntity()