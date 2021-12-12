import netty
export netty

import tables
export tables

import nimraylib_now/mangled/raylib # Vector2
export raylib

import nimraylib_now/mangled/raymath # Vector2
export raymath

import std/parsecfg
export parsecfg

import ecs
export ecs

import chipmunk7
export chipmunk7

import ../shared/typesAssetLoader
export typesAssetLoader

import ../shared/shared

type
  WorldmapPos* = Vector2
  CompPlayerServer* = ref object of Component
    id*: Id
    connection*: Connection
    pos*: Vector2
  CompMap* = ref object of Component
    space*: chipmunk7.Space
  GServer* = ref object
    players*: Table[Id, CompPlayerServer]
    server*: Reactor
    config*: Config
    targetServerFps*: uint8
    targetServerPhysicFps*: uint8
    assets*: AssetLoader
    reg*: Registry
    maps*: Table[WorldmapPos, Entity]

    # threadPhysic*: Thread[GServer] # codegen bug