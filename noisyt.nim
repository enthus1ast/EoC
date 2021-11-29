import benchy, noisy, strformat

var simplex = initSimplex(1988) # 1988 is the random seed, generate this however
simplex.octaves = 3
simplex.frequency = 4
simplex.amplitude = 0.2
simplex.lacunarity = 1.5
simplex.gain = 4.3

timeIt "2d 255 x 255":
  var c: float
  for x in 0 ..< 254:
    for y in 0 ..< 254:
      c += simplex.value(x, y)
  keep(c)

# timeIt "2d simd 4096x4096":
#   var c: float
#   let g = simplex.grid((0, 0), (4096, 4096))
#   for value in g.values:
#     c += value
#   keep(c)

# timeIt "3d 256x256x256":
#   var c: float
#   for x in 0 ..< 256:
#     for y in 0 ..< 256:
#       for z in 0 ..< 256:
#         c += simplex.value(x, y, z)
#   keep(c)

# timeIt "3d simd 256x256x256":
#   var c: float
#   let g = simplex.grid((0, 0, 0), (256, 256, 256))
#   for value in g.values:
#     c += value
#   keep(c)

#[
-d:release
name ............................... min time      avg time    std dv   runs
2d 4096x4096 .................... 1518.958 ms   1542.219 ms   ±19.960     x4
2d simd 4096x4096 ............... 1038.734 ms   1047.763 ms    ±8.763     x5
3d 256x256x256 .................. 1952.877 ms   1961.227 ms    ±8.073     x3
3d simd 256x256x256 ............. 1528.155 ms   1540.937 ms   ±14.416     x4

-d:release -d:lto
name ............................... min time      avg time    std dv   runs
2d 4096x4096 .................... 1497.344 ms   1535.666 ms   ±29.030     x4
2d simd 4096x4096 ................ 906.395 ms    940.286 ms   ±30.440     x6
3d 256x256x256 .................. 2048.985 ms   2062.864 ms   ±15.543     x3
3d simd 256x256x256 ............. 1428.455 ms   1432.321 ms    ±3.134     x4

-d:release -d:lto --passC:"-mavx"
name ............................... min time      avg time    std dv   runs
2d 4096x4096 .................... 1183.832 ms   1215.614 ms   ±24.529     x5
2d simd 4096x4096 ................ 574.969 ms    593.936 ms   ±12.163     x9
3d 256x256x256 .................. 1698.823 ms   1706.525 ms    ±6.857     x3
3d simd 256x256x256 ............. 1012.736 ms   1028.312 ms   ±18.237     x5

-d:release -d:danger -d:lto --passC:"-mavx"
name ............................... min time      avg time    std dv   runs
2d 4096x4096 .................... 1176.552 ms   1200.798 ms   ±27.885     x5
2d simd 4096x4096 ................ 544.511 ms    570.152 ms   ±22.527     x9
3d 256x256x256 .................. 1664.574 ms   1688.115 ms   ±27.758     x3
3d simd 256x256x256 .............. 953.314 ms    976.140 ms   ±25.356     x6

-d:release -d:danger -d:lto --passC:"-mavx" --gc:orc
]#