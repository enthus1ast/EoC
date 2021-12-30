import ../client/typesClient
import ../server/typesServer
import ecs
import nimraylib_now
import shared

type
  CompAnimation* = ref object of Component
    enabled*: bool
    pixelPos*: Vector2
    loop*: bool
    spritesheetKey*: Key
    keyframes*: seq[string] # the frame names from the spritesheet
    current*: string
    duration*: float
    progress*: float

proc update(compAnimation: CompAnimation, delta: float) =
  compAnimation.progress.addOverflow(delta, maxval = compAnimation.duration)
  # print compAnimation.progress, compAnimation.duration
  let elem = floor(compAnimation.progress / (compAnimation.duration / compAnimation.keyframes.len.float) ).int.clamp(0,  compAnimation.keyframes.len - 1)
  compAnimation.current = compAnimation.keyframes[elem]

proc systemAnimation*(gclient: GClient, delta: float) =
  for entAnim in gclient.reg.entities(CompAnimation):
    var compAnimation = gclient.reg.getComponent(entAnim, CompAnimation)
    compAnimation.update(delta)