import typesClient
import nimraylib_now

import netlib
import assetLoader
import typesAssetLoader
import nim_tiled
import std/intsets
var screenWidth = 800
var screenHeight = 450

proc centerCamera(gclient: GClient) =
  ## center the camera on the player
  gclient.camera.offset.x = getScreenWidth() / 2
  gclient.camera.offset.y = getScreenHeight() / 2

proc getWorldMousePosition(gclient: GClient): Vector2 =
  ## get the mouseposition respecting the camera.
  return getScreenToWorld2D(getMousePosition(), gclient.camera)

proc drawGrid(gridsize: int, offset: Vector2, color = Black) =
  drawRectangleLines(0 + offset.x.int, 0 + offset.y.int, gridsize, gridsize, color)
  for idx in 0 .. (gridsize div 32) - 1:
    drawLine((idx * 32) + offset.x.int, 0 + offset.y.int, (idx * 32) + offset.x.int, gridsize + offset.y.int, color)
    drawLine(0 + offset.x.int, (idx * 32) + offset.y.int, gridsize + offset.x.int, (idx * 32) + offset.y.int, color)

converter toReg(tiledRegion: TiledRegion): Rectangle =
  return Rectangle(
    x: tiledRegion.x.float,
    y: tiledRegion.y.float,
    width: tiledRegion.width.float,
    height: tiledRegion.height.float,
  )

proc toVecs(points: seq[(float, float)], pos: Vector2): seq[Vector2] =
  result = @[]
  for point in points:
    result.add Vector2(x: point[0] + pos.x, y: point[1] + pos.y)

proc drawTilemap*(gclient: GClient, map: TiledMap) =
  let tileset = map.tilesets()[0]
  let texture = gclient.assets.textures[tileset.imagePath()]
  for layer in map.layers:
    for xx in 0..<layer.height:
      for yy in 0..<layer.width:
        let index = xx + yy * layer.width
        let gid = layer.tiles[index]
        if gid != 0:
          let region = tileset.regions[gid - 1]
          let sourceReg = Rectangle(x: region.x.float, y: region.y.float, width: region.width.float, height: region.height.float)
          let destPos = Vector2(x: (xx * map.tilewidth).float, y: (yy * map.tileheight).float)
          drawTextureRec(texture, sourceReg, destPos, White)

          ## Tile Collision shapes
          if tileset.tiles.hasKey(gid - 1): # ids are are not correct in tiled tmx
            let collisionShapes = tileset.tiles[gid - 1].collisionShapes
            for collisionShape in collisionShapes:
              case collisionShape.kind
              of kindTiledTileCollisionShapesRect:
                discard
                let rect = TiledTileCollisionShapesRect(collisionShape)
                # print rect, destPos
                # print rect.x.int + destPos.x.int, rect.y.int + destPos.y.int, rect.width.int, rect.height.int, Yellow
                drawRectangleLines(rect.x.int + destPos.x.int, rect.y.int + destPos.y.int, rect.width.int, rect.height.int, Yellow)

              of kindTiledTileCollisionShapesPoint:
                discard
                print kindTiledTileCollisionShapesPoint, "not support"
              else:
                discard # unsupported shape

  # Now we debug draw the polygons
  # we must later decide what we do with the polygons
  for objectGroup in map.objectGroups:
    # nim_tiled cannot show which TiledObject we have
    # but we know that these are polygons
    # void DrawLineStrip(Vector2 *points, int pointsCount, Color color);   // Draw lines sequence
    let color =
      case objectGroup.name
      of "Exit": Red
      of "Next": Green
      else: Black
    for obj in objectGroup.objects:
      # print obj
      var vecs = toVecs(TiledPolygon(obj).points, (obj.x, obj.y))
      # print vecs
      drawLineStrip(addr vecs[0], vecs.len, color)

proc systemDraw*(gclient: GClient) =
  # var testSprite: Texture2D = loadTexture(getAppDir() / "assets/img/test.png")
  beginDrawing()
  gclient.centerCamera()
  # echo gclient.circle.position
  for idx, msg in enumerate(gclient.serverMessages):
    drawText( $msg , 0, 0 + ((screenHeight div 2) + (15 * idx)), 10, Darkgray)



  case gclient.clientState
  of MAIN_MENU:
    clearBackground(Yellow)
    # if (GuiTextBox((Rectangle){ 25, 215, 125, 30 }, textBoxText, 64, textBoxEditMode)) textBoxEditMode = !textBoxEditMode;
    # proc textBox*(bounds: Rectangle; text: cstring; textSize: cint; editMode: bool): bool
    # var text: cstring
    # if text.isNil:
    #   text = newString(512)
    if textBox(Rectangle(x: 10, y:10, width:150, height:30), gclient.txtServer , textSize = 512, editMode = true):
      echo "TEXT BOX:", gclient.txtServer

    var btnConnect = button(Rectangle(x: 10, y:50, width:50, height:30), "Connect")
    if btnConnect:
      echo "CONNECT"
      gclient.connect($gclient.txtServer)
  of CONNECTING:
    clearBackground(Red)
    let text = fmt"Connecting to server: {gclient.txtServer}"
    drawText(text, 10, 10, 20, Black)
  of WORLD_MAP:
    # here we render the prebuild worldmap
    # all the locations
    # tents etc.
    discard
    clearBackground(White)
    # drawRectangle(0, 0, 1024, 1024, BLACK)

    # beginMode2D gclient.camera
    # gclient.centerCamera()
    # drawWorldMapMouseCoord()
    let wmp = getMousePosition()
    let mapSize = 512
    let quadSize = 32
    let quadCount = mapSize div quadSize
    let xcord = ceil(wmp.x / (mapSize / quadCount)).int
    let ycord = ceil(wmp.y / (mapSize / quadCount)).int

    if (xcord > 0 and xcord <= quadCount) and (ycord > 0 and ycord <= quadCount) :
      let msg = fmt"{xcord}x{ycord}  ({wmp.x}x{wmp.y})"
      let mp = getMousePosition()
      drawText(msg, mp.x.int, (mp.y + 25).int, 12, Black)

    # drawGrid(mapSize, (10.0, 10.0))
    drawGrid(mapSize, (0.0, 0.0))
    # endMode2D()

  of MAP:
    beginMode2D gclient.camera
    gclient.camera.target = gclient.reg.getComponent(gclient.myPlayer(), CompPlayer).pos
    let curTime = getMonoTime()
    # clearBackground(Raywhite)
    clearBackground(Black)



    # Draw some testimages
    # for idxy in 0..50:
    #   for idxx in 0..50:
    #     drawTexture(
    #       gclient.assets.textures["assets/img/test.png"],
    #       0 + (idxx * 32),
    #       0 + (idxy * 32),
    #       White
    #     )

    gclient.drawTilemap(gclient.assets.maps["assets/maps/demoTown.tmx"])

    # let mousePos = getMousePosition()
    let mousePos = gclient.getWorldMousePosition()
    # drawCircle(playerPos.x.int, playerPos.y.int, 5, LIGHTGRAY)

    drawCircle(mousePos.x.int, mousePos.y.int, 10, Blue)
    # draw all other players
    for id, entPlayer in gclient.players:
      let compPlayer = gclient.reg.getComponent(entPlayer, CompPlayer)
      let compName = gclient.reg.getComponent(entPlayer, CompName)
      if id == gclient.myPlayerId:
        ## This is us, we can draw us directly
        drawText($compPlayer.id, compPlayer.pos.x.int - 20 , compPlayer.pos.y.int - 20 , 10, Blue)
        drawCircle(compPlayer.pos.x.int, compPlayer.pos.y.int, 5, RED)
      else:
        ## these are others, more logic apply
        try:
          ## We must interpolate between the `oldpos` and the `newpos`
          let dif = (curTime - compPlayer.lastmove).inMilliseconds.int.clamp(0, 50_000)
          let serverTickTime = calculateFrameTime(gclient.targetServerFps) # TODO ~5fps
          let percent = dif / serverTickTime
          # print (curTime - compPlayer.lastmove).inMilliseconds, dif, percent
          let moveVec = compPlayer.pos - compPlayer.oldpos

          let interpolated =  compPlayer.oldpos + (moveVec * percent)

          drawText($compPlayer.id, interpolated.x.int - 20, interpolated.y.int - 35 , 15, Black)
          drawText(compName.name, interpolated.x.int - 20, interpolated.y.int - 20 , 15, Black)
          drawCircle(interpolated.x.int, interpolated.y.int, 5, RED)
        except:
          echo getCurrentExceptionMsg()
      # print dif

    ##DEBUG
    # let texture = gclient.assets.textures["assets\\img\\tilesets\\demo.png"] # todo get this from the map
    # drawTextureRec(texture, Rectangle(x: 0.float, y: 0.float, width: 50.float, height: 50.float), (10.float, 10.float), White)

    # Draw the tilemap



    endMode2D()



    # drawText("FRAME SPEED: ", 165, 210, 10, Darkgray)
    drawText("Entities: " & $gclient.reg.validEntities.len() , 0, getScreenHeight() - 20, 10, Darkgray)
    drawText("FPS: " & $getFPS() , 0, getScreenHeight() - 10, 10, Darkgray)
    drawText("Unacknowledged moves: " & $gclient.moves.len , 10, 10, 10, Darkgray)
  endDrawing()