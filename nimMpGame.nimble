# Package

version       = "0.1.0"
author        = "David Krause"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.0"
requires "noisy" # perlin noise generator, map generation etc
requires "https://github.com/treeform/netty.git#483bb7321469f098b4c360c3aa6c277c34b2d878" # udp networking library
requires "nimscripter" # scripting library
requires "nimraylib_now" # raylib bindings render / multimedia library
requires "flatty" # binary serialisation library
requires "supersnappy" # compression library
# requires "print" # better echo
requires "https://github.com/treeform/print.git"
# requires "https://github.com/avahe-kellenberger/nim-chipmunk.git" # 2d Physic engine
requires "https://github.com/enthus1ast/nim-chipmunk.git == 7.0.4"
# requires "chipmunk7" # 2d Physic engine

# requires "https://github.com/SkyVault/nim-tiled.git" # Tiled loader
requires "https://github.com/enthus1ast/nim-tiled.git" # Tiled Loader
requires "https://github.com/enthus1ast/ecs.git" # entity component system


let
  buildClientLinux = "nim c -d:release --gc:arc --threads:on --passl:-s -d:lto src/client/testi.nim"
  buildServerLinux = "nim c -d:release --gc:arc --threads:on --passl:-s -d:lto src/server/server.nim"
  buildClientWindows = "nim c --os:windows --cpu:amd64 --gcc.exe:x86_64-w64-mingw32-gcc -d:release --gc:arc --threads:on --passl:-s -d:lto src/client/testi.nim"
  buildServerWindows = "nim c --os:windows --cpu:amd64 --gcc.exe:x86_64-w64-mingw32-gcc -d:release --gc:arc --threads:on --passl:-s -d:lto src/server/server.nim"

task buildlinuxclient, "Build client for linux":
  exec buildClientLinux

task buildlinuxserver, "Build server for linux":
  exec buildServerLinux


task buildwindowsclient, "Build client for windows (crosscompile)":
  exec buildClientWindows

task buildwindowsserver, "Build server for windows (crosscompile)":
  exec buildServerWindows

task buildall, "builds all":
  exec buildClientLinux
  exec buildServerLinux
  exec buildClientWindows
  exec buildServerWindows