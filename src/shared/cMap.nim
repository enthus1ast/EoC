import ../client/typesClient
import ../server/typesServer
import ecs
import chipmunk7
import nimraylib_now
import nim_tiled

type
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

proc generateMapCollisionBoundaries(gclient: GClient | GServer, map: TiledMap, compTilemap: CompTilemap) =
  ## Generate the map collision boundaries
  ## (the walls around the map)
  let widthPixel = (map.width * map.tilewidth).float
  let heightPixel = (map.height * map.tileheight).float
  compTilemap.mapBoundaryBody = addBody(gclient.physic.space, newStaticBody())
  for (idx, line) in enumerate gen4Lines[Vect](x = 0.0, y = 0.0, width = widthPixel, height = heightPixel):
    compTilemap.mapBoundarieShapes[idx] = gclient.physic.space.addShape(
      newSegmentShape(compTilemap.mapBoundaryBody, line.aa, line.bb, 2)
    )

iterator tiles*(layer: TiledLayer): tuple[xx: int, yy: int, index: int, gid: int] =
  ## yields all tile infos from a tiled layer
  for xx in 0..<layer.height:
    for yy in 0..<layer.width:
      let index = xx + yy * layer.width
      yield (
        xx: xx,
        yy: yy,
        index: index,
        gid: layer.tiles[index]
      )

proc newMap*(gclient: GClient | GServer, mapKey: string): Entity =
  ## Creates a new tilemap entity,
  echo "Loading map"
  result = gclient.reg.newEntity()
  let map = gclient.assets.maps[mapKey]
  var compTilemap = CompTilemap()

  gclient.generateMapCollisionBoundaries(map, compTilemap)

  ## TODO this is mostly copied from the systemDraw, deduplicate code
  let tileset = map.tilesets()[0]
  let texture = gclient.assets.textures[tileset.imagePath()]
  for layer in map.layers:
    for (xx, yy, index, gid) in layer.tiles:
      let entTile = gclient.reg.newEntity()
      compTilemap.tiles[Vector2(x: xx.float, y: yy.float)] = entTile
      var compTile = CompTile(xtile: xx, ytile: yy)
      gclient.reg.addComponent(entTile, compTile)
      if gid != 0:
        let region = tileset.regions[gid - 1]
        let destPos = Vector2(x: (xx * map.tilewidth).float, y: (yy * map.tileheight).float)
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
            # createCollision
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
                newPolyShape(compTilemap.tileCollisionBodies[index], poly.points.len , addr vecs[0], 1)
              )
              shape.friction = 0
              compTileCollision.shapes.add shape
              compTilemap.tileCollisionShapes[index].add shape # TODO remove
            else:
              echo "Collision shape not Supported: ", collisionShape.type
            gclient.reg.addComponent(entTile, compTileCollision)


  echo "Creating layer shapes"
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
        var vecs = poly.points.toVecsChipmunks((0.0, 0.0))
        compTilemapObject.shape = addShape(gclient.physic.space,
          newPolyShape(compTilemapObject.body, poly.points.len , addr vecs[0], 1)
        )
      else:
        # Rectangle
        print obj.id
        compTilemapObject.body = addBody(gclient.physic.space, newStaticBody())
        compTilemapObject.body.position = v(obj.x + (obj.width / 2), obj.y + (obj.height / 2))
        compTilemapObject.shape = addShape(gclient.physic.space,
          newBoxShape(compTilemapObject.body, obj.width, obj.height, radius = 1)
        )
      # TODO create collisions from the rest of the obj shapes
      gclient.reg.addComponent(entTilemapObj, compTilemapObject)

  echo "done"

  ## Register destructor
  proc compTilemapDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    gprint "in implicit internal tilemap destructor: "
    var compTilemap = CompTilemap(comp)

    ## Invalidate all the tiles, they will get freed later
    for entTile in compTilemap.tiles.values:
      gclient.reg.invalidateEntity(entTile)

  # Register in the ecs
  gclient.reg.addComponentDestructor(CompTilemap, compTilemapDestructor)

  proc compTileCollisionDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    gprint "in implicit internal CompTileCollision destructor: "
    for shape in CompTileCollision(comp).shapes:
      gclient.physic.space.removeShape(shape)
    gclient.physic.space.removeBody(CompTileCollision(comp).body)
  gclient.reg.addComponentDestructor(CompTileCollision, compTileCollisionDestructor)

  proc compCompTilemapObjectDestructor(reg: Registry, entity: Entity, comp: Component) {.closure, gcsafe.} =
    gprint "in implicit internal CompTilemapObject destructor: "
    gclient.physic.space.removeShape(CompTilemapObject(comp).shape)
    gclient.physic.space.removeBody(CompTilemapObject(comp).body)
  gclient.reg.addComponentDestructor(CompTilemapObject, compCompTilemapObjectDestructor)

