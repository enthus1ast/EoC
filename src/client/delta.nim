import std/monotimes, times, os
import print
type
  Delta* = object
    targetFps: int
    last: MonoTime
    cur: MonoTime

proc newDelta*(targetFps: int): Delta =
  result.targetFps = targetFps
  result.last = getMonoTime()
  result.cur = getMonoTime()

proc tick*(delta: var Delta) =
  delta.last = delta.cur
  delta.cur = getMonoTime()

proc getDelta*(delta: var Delta): Duration =
  result = delta.cur - delta.last

proc sleepTime*(delta: var Delta): int =
  ## Sleeps so that we tick at `targetFps`
  let dl = delta.getDelta()
  let target = (1000 / delta.targetFps).int
  print dl.inMilliseconds, target, target - dl.inMilliseconds
  # let sleepTime =  (target - dl.inMilliseconds()).clamp(0, 50_000)
  let sleepTime =  (target - dl.inMilliseconds())
  print sleepTime
  if sleepTime > 0:
    sleep(sleepTime.int)
  # else:
    # sleep(target)
  # let sleepTime =  ( dl.inMilliseconds - (1000 / delta.targetFps).int).clamp(0, 50_0000)
  # print sleepTime,  dl.inMilliseconds, dl
  # sleep(dl.inMilliseconds.int)
  # sleep(sleepTime.int)

# proc getDeltaInMili(delta: var Delta): int =
#   let cur = getMonoTime()
#   result = cur - delta.last
#   delta.last = cur
import random
proc main() =
  sleep(rand(30))

when isMainModule:
  import os
  var delta = newDelta(24)
  var idx = 0
  let tar = (1000 / delta.targetFps).int

  while true:

    let startt = getMonoTime()
    main()
    let endt = getMonoTime()

    let took = (endt - startt).inMilliseconds
    let sleepTime = (tar - took).clamp(0, 50_000)
    print took, sleepTime, took + sleepTime, tar

    sleep(sleepTime.int)


    # let dl = delta.getDelta()
    # let dlm = dl.inMilliseconds()
    # let st = (tar - dlm).clamp(0, 50_000)
    # print dlm, st
    # sleep(st.int)

    # # sleep(rand(350) + 50) # simulate lag
    # sleep(300)
    # # sleep(300 + idx)
    # idx.inc(100)


    # delta.tick()
    # sleep(delta.sleepTime())

    # let del = delta.getDelta()
    # echo del, del.inMilliseconds()
  # sleep(50)
  # echo delta.getDelta()
  # sleep(50)
  # echo delta.getDelta()

