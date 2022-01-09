import strutils, strscans
type
  CliKind* = enum
    unknown
    help
    maps
    lock
    unlock
    players
    tele
    teleWorldmap
    toWorldmap

  # TODO this case obj is super shit, this must be done: https://github.com/nim-lang/RFCs/issues/368
  CliObj* = object
    case kind*: CliKind
    of tele:
      teleEnt*: int
      teleXX*: float
      teleYY*: float
    of teleWorldmap:
      teleWorldmapEnt*: int
      teleWorldmapXX*: float
      teleWorldmapYY*: float
    of toWorldmap:
      toWorldmapEnt*: int
    else: discard


proc cli*(): CliObj =
  stdout.write(": ")
  stdout.flushFile()
  let line = stdin.readLine().strip()
  let parts = split(line, maxsplit = 1)
  if parts.len == 0: return
  var op: CliKind = unknown
  try:
    op = parseEnum[CliKind](parts[0])
  except:
    echo "unknown command: ", parts[0]

  case op
  of help:
    echo "Valid commands:"
    for elem in CliKind:
      echo $elem
  of unknown, maps, lock, unlock, players:
    return CliObj(kind: op)
  of tele:
    if parts.len == 2:
      var obj = CliObj(kind: op)
      if scanf(parts[1], "$i $fx$f", obj.teleEnt, obj.teleXX, obj.teleYY):
        return obj
  of teleWorldmap:
    if parts.len == 2:
      var obj = CliObj(kind: op)
      if scanf(parts[1], "$i $fx$f", obj.teleWorldmapEnt, obj.teleWorldmapXX, obj.teleWorldmapYY):
        return obj
  of toWorldmap:
    if parts.len == 2:
      var obj = CliObj(kind: op)
      if scanf(parts[1], "$i", obj.toWorldmapEnt):
        return obj
  else: discard


when isMainModule:
  while true:
    echo cli()