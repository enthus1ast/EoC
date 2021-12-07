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
  # result.space.damping = 0.1

proc systemPhysic*(gclient: GClient, delta: float) =
  # ## Slow players down over time
  # for entPlayer in gclient.reg.entities(CompPlayer):
  #   var compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
  #   compPlayer.body.velocity = compPlayer.body.velocity * 0.95



  gclient.physic.space.step(delta)
