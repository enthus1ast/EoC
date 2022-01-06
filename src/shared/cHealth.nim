import ../client/typesClient
import ../server/typesServer
import ecs
import nimraylib_now

type
  CompHealth* = ref object of Component
    health*: float
    maxHealth*: float

proc isDeath*(compHealth: CompHealth): bool =
  return compHealth.health <= 0

proc isAlive*(compHealth: CompHealth): bool =
  return not compHealth.isDeath()

proc isDamaged*(compHealth: CompHealth): bool =
  return compHealth.health < compHealth.maxHealth

proc kill*(compHealth: CompHealth) =
  compHealth.health = 0

proc damage*(compHealth: CompHealth, dmg: int | float) =
  compHealth.health -= dmg.abs()

proc heal*(compHealth: CompHealth, heal: int | float) =
  if compHealth.health > 0: # can't heal the death # TODO these messages must be evented to the client
    compHealth.health += heal.abs()
    compHealth.health = compHealth.health.clamp(0, compHealth.maxHealth)

proc systemHealth*(gobj: GClient | GServer, delta: float) =
  ## TODO this is just a dummy system for now.
  for (entHealth, compHealth) in gobj.reg.entitiesWithComp(CompHealth):
    compHealth.heal(10 * delta)