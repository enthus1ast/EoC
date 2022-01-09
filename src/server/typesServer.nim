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

import flatty
export flatty

import ../shared/typesAssetLoader
export typesAssetLoader

import typesSystemMaps
export typesSystemMaps

import ../shared/shared

import std/locks

import intsets
export intsets


type
  WorldmapPos* = Vector2
  CompPlayerServer* = ref object of Component
    id*: Id
    connection*: Connection
    pos*: Vector2
  GServer* = ref object
    players*: Table[Id, Entity] # Netty connection id -> Entity
    server*: Reactor
    config*: Config
    targetServerFps*: uint8
    targetServerPhysicFps*: uint8
    assets*: AssetLoader
    reg*: Registry
    maps*: Table[WorldmapPos, Entity]
    systemMaps*: SystemMaps

    lock*: Lock

    networkThread*: Thread[ptr GServer]
    physicThread*: Thread[ptr GServer]

    # threadPhysic*: Thread[GServer] # codegen bug