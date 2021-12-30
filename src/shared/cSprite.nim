import ecs
from nimraylib_now import Vector2


type
  CompSprite* = ref object of Component
    enabled*: bool ## if true draw the sprite
    img*: string # TODO this should be Key
    pixelPos*: Vector2