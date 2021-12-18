import std/[monotimes, os, times, math]
import shared
when defined(windows):
  from winim import timeBeginPeriod, UINT

type
  DeltaCalculator = ref object
    targetFps: int
    frameTime: int
    delta: float
    startt: MonoTime
    endt: MonoTime
    took: int64
    sleepTime: int64

proc deltaInMs*(dc: DeltaCalculator): float =
  return dc.delta

proc delta*(dc: DeltaCalculator): float =
  return dc.delta / 1000

proc newDeltaCalculator*(targetFps: int, timerAccuracy = 1): DeltaCalculator =
  when defined(windows):
    if timerAccuracy > -1:
      timeBeginPeriod(UINT(timerAccuracy))
  result = DeltaCalculator()
  result.targetFps = targetFps
  result.frameTime = calculateFrameTime(targetFps = targetFps)
  result.delta = result.frameTime.float

proc startFrame*(dc: DeltaCalculator) =
  dc.startt = getMonoTime()

proc endFrame*(dc: DeltaCalculator) =
  dc.endt = getMonoTime()
  dc.took = (dc.endt - dc.startt).inMilliseconds
  dc.sleepTime = (dc.frameTime - dc.took).clamp(0, 50_000)
  dc.delta = dc.took.float + dc.sleepTime.float

proc sleep*(dc: DeltaCalculator) =
  # echo dc.sleepTime
  sleep(dc.sleepTime.int)

when isMainModule:
  var dc = newDeltaCalculator(120)
  while true:
    # echo dc.delta
    # echo dc.delta, " ", calculateFrameTime(dc.targetFps)
    if dc.delta.int > calculateFrameTime(dc.targetFps).int:
      echo "TO SLOW:", $dc.delta
    dc.startFrame()
    sleep(3)
    dc.endFrame()
    dc.sleep()