import math
import nimraylib_now
import shared
import json
import tables
import print
import strformat
import std/monotimes
import std/times
import std/enumerate
import asyncdispatch
import chatbox
import netty, os, flatty
import typesAssetLoader


export math
export nimraylib_now
export shared
export json
export tables
export print
export strformat
export monotimes
export times
export enumerate
export asyncdispatch
export chatbox
export netty, os, flatty
export typesAssetLoader


type
  Player* = object # is player == crit (critter)?
    id*: Id
    oldpos*: Vector2 # we tween from oldpos
    pos*: Vector2    # to newpos in a "server tick time step"
    lastmove*: MonoTime

  GClient* = ref object
    nclient*: Reactor
    clientState*: ClientState
    c2s*: Connection
    # players*: Table[Id, Vector2]
    players*: Table[Id, Player]
    myPlayerId*: Id
    connected*: bool

    # Main Menu
    txtServer*: cstring
    moveId*: int32
    # moves*: Table[int32, GReqPlayerMoved]
    moves*: Table[int32, Vector2]

    targetServerFps*: uint8

    serverMessages*: Chatbox

    camera*: Camera2D

    assets*: AssetLoader