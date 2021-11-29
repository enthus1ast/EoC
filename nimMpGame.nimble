# Package

version       = "0.1.0"
author        = "David Krause"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.0"
requires "noisy" # perlin noise generator, map generation etc
requires "netty" # udp networking library
requires "nimscripter" # scripting library
requires "nimraylib_now" # raylib bindings render / multimedia library
requires "flatty" # binary serialisation library
requires "supersnappy" # compression library
requires "print" # better echo