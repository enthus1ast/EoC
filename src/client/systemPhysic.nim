# The client side systemPhysic is the client prediction path
# The server also runs its own systemPhysic
# While the client side systemPhysic only runs on the
# currently loaded map, the server side one must run on ALL the maps.

import typesClient

import typesSystemPhysic
export typesSystemPhysic

proc newSystemPhysic*(): SystemPhysic =
  result = SystemPhysic()
  result.space = newSpace()
  result.space.gravity = v(0, 0)

proc systemPhysic*(gclient: GClient, delta: float) =
  discard

  gclient.physic.space.step(delta)
