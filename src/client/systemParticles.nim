# A simple particle system.
import typesClient

type
  CompLivetime = ref object of Component ## TODO this can be shared
    livetime: float
  CompVelocity = ref object of Component ## TODO this can be shared
    linear: Vector2
    angular: float

proc makeParticles(gclient: GClient, cnt: int) =
  for idx in 1..cnt:
    let entParticle = gclient.reg.newEntity()
