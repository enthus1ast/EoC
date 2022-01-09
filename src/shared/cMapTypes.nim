import shared, chipmunk7
from nimraylib_now import Vector2

type
  CompMap* = ref object of Component
    space*: chipmunk7.Space
    players*: IntSet

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