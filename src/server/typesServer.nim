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

import ../shared

type
  Player* = object
    id*: Id
    connection*: Connection
    pos*: Vector2
  GServer* = ref object
    players*: Table[Id, Player]
    server*: Reactor
    config*: Config
    targetServerFps*: uint8
    reg*: Registry