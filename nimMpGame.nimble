# Package

version       = "0.1.0"
author        = "David Krause"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.0"
requires "noisy" # perlin noise generator, map generation etc
requires "netty@#head" # udp networking library
requires "nimscripter" # scripting library
requires "nimraylib_now" # raylib bindings render / multimedia library
requires "flatty" # binary serialisation library
requires "supersnappy" # compression library
# requires "print" # better echo
requires "https://github.com/treeform/print.git"
requires "https://github.com/avahe-kellenberger/nim-chipmunk.git" # 2d Physic engine
# requires "https://github.com/SkyVault/nim-tiled.git" # Tiled loader
requires "https://github.com/enthus1ast/nim-tiled.git" # Tiled Loader
requires "https://github.com/enthus1ast/ecs.git" # entity component system