##[
  The Servers physic system is different from the client one.
  Its must simulate all the loaded maps at once.
  Also each map needs to have its own physic space.

  The physic system should spawn a thread for each loaded map, to calculate the physic in
  parallel for each map.

  For the demo we will only simulate one map.
]##

import typesServer


proc systemPhysic(gserver: GServer, delta: float) =
  discard