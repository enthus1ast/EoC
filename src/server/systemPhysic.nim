##[
  The Servers physic system is different from the client one.
  It must simulate all the loaded maps at once.
  Also each map needs to have its own physic space.

  The physic system should spawn a thread for each loaded map, to calculate the physic in
  parallel for each map.

  For the demo we will only simulate one map.
]##
import std/locks
import std/[os, times, monotimes]
import typesServer
import ../shared/shared
import ../shared/cPlayer
import ../shared/cMapTypes
import ../shared/deltaCalculator
import chipmunk7


proc systemPhysic*(ptrgserver: ptr GServer, delta: float) {.gcsafe.} =
  var gserver = ptrgserver[]

  for (entPlayer, compPlayer) in gserver.reg.entitiesWithComp(CompPlayer):
    # gprint compPlayer.controlBody.position, compPlayer.controlBody.position - compPlayer.body.position

    let diff = (compPlayer.desiredPosition - compPlayer.body.position)
    # print diff
    if diff.length().abs < 5:
      compPlayer.controlBody.velocity = vzero
    else:
      compPlayer.controlBody.velocity = (diff.normalize() * 100) #* delta

    # print compPlayer.controlBody.velocity
    # compPlayer.controlBody.velocity = (compPlayer.controlBody.position - compPlayer.body.position).normalize()
    # if compPlayer.controlBody.velocity.length < 1.0:
    #   compPlayer.controlBody.velocity = vzero
    #   compPlayer.controlBody.position = compPlayer.body.position

    # if compPlayer.controlBody.velocity.length < 1.0:
    #   compPlayer.controlBody.velocity = vzero

  for entMap in gserver.reg.entities(CompMap):
    # echo entMap
    var compMap = gserver.reg.getComponent(entMap, CompMap)
    compMap.space.step(delta)


proc systemPhysicThread*(ptrgserver: ptr GServer) {.thread, gcsafe.} =
  var gserver = ptrgserver[]
  var dc = newDeltaCalculator(gserver.targetServerPhysicFps.int)
  while true:
    dc.startFrame()
    gserver.lock.acquire()
    ptrgserver.systemPhysic(dc.delta())
    gserver.lock.release()
    dc.endFrame()
    dc.sleep()