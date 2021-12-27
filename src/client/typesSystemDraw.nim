from nimraylib_now import Camera2D
type
  SystemDraw* = object
    screenWidth*: int
    screenHeight*: int
    debugDraw*: bool
    camera*: Camera2D