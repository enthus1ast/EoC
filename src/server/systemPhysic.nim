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
import chipmunk7
import print
# import


proc systemPhysic*(gserver: GServer, delta: float) =
  echo "physic tik"
  for entMap in gserver.reg.entities(CompMap):
    # echo entMap
    var compMap = gserver.reg.getComponent(entMap, CompMap)
    compMap.space.step(delta)

proc threadSystemPhysic*(gserver: GServer) = #{.thread.} =
  let tar = calculateFrameTime(gserver.targetServerPhysicFps)
  var delta = 0.1
  while true:
    let startt = getMonoTime()
    gserver.systemPhysic(delta)
    let endt = getMonoTime()
    let took = (endt - startt).inMilliseconds
    # print took
    let sleepTime = (tar - took).clamp(0, 50_000)
    sleep(sleepTime.int)

